/*
 * Copyright (c) 2010-2017 OTClient <https://github.com/edubart/otclient>
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

#include "protocol.h"
#include "connection.h"
#include <framework/core/application.h>
#include <random>

#include <framework/net/packet_player.h>
#include <framework/net/packet_recorder.h>

extern asio::io_context g_ioService;

Protocol::Protocol()
{
    m_xteaEncryptionEnabled = false;
    m_checksumEnabled = false;
    m_sequencedPackets = false;
    m_bigPackets = false;
    m_compression = false;
    m_inputMessage = std::make_shared<InputMessage>();
    m_packetNumber = 0;

    // compression
    m_zstreamBuffer.resize(InputMessage::BUFFER_MAXSIZE);
    m_zstream.next_in = m_inputMessage->getDataBuffer();
    m_zstream.next_out = m_zstreamBuffer.data();
    m_zstream.avail_in = 0;
    m_zstream.avail_out = 0;
    m_zstream.total_in = 0;
    m_zstream.total_out = 0;
    m_zstream.zalloc = nullptr;
    m_zstream.zfree = nullptr;
    m_zstream.opaque = nullptr;
    m_zstream.data_type = Z_BINARY;
    inflateInit2(&m_zstream, -15);
}

Protocol::~Protocol()
{
    VALIDATE(!g_app.isTerminated());
    disconnect();
    inflateEnd(&m_zstream);
}

void Protocol::connect(const std::string& host, uint16 port)
{
    if (host == "proxy" || host == "0.0.0.0" || (host == "127.0.0.1" && g_proxy.isActive())) {
        m_disconnected = false;
        m_proxy = g_proxy.addSession(port,
                                     std::bind(&Protocol::onProxyPacket, asProtocol(), std::placeholders::_1),
                                     std::bind(&Protocol::onLocalDisconnected, asProtocol(), std::placeholders::_1));
        return onConnect();
    }
    m_connection = std::make_shared<Connection>();
    m_connection->setErrorCallback(std::bind(&Protocol::onError, asProtocol(), std::placeholders::_1));
    m_connection->connect(host, port, std::bind(&Protocol::onConnect, asProtocol()));
}

void Protocol::disconnect()
{
    m_disconnected = true;
    if (m_player) {
        m_player->stop();
        return;
    }
    if (m_proxy) {
        if (g_proxy.isWorking()) {
            g_proxy.removeSession(m_proxy);
        }
        m_proxy = 0;
        return;
    }
    if (m_connection) {
        m_connection->close();
        m_connection.reset();
    }
}


void Protocol::playRecord(PacketPlayerPtr player)
{
    m_disconnected = false;
    m_player = player;
    m_player->start(std::bind(&Protocol::onPlayerPacket, asProtocol(), std::placeholders::_1),
                    std::bind(&Protocol::onLocalDisconnected, asProtocol(), std::placeholders::_1));
    return onConnect();
}

void Protocol::setRecorder(PacketRecorderPtr recorder)
{
    m_recorder = recorder;
}

bool Protocol::isConnected()
{
    if (m_player)
        return !m_disconnected;
    if (m_proxy)
        return !m_disconnected;
    if (m_connection && m_connection->isConnected())
        return true;
    return false;
}

bool Protocol::isConnecting()
{
    if (m_player)
        return false;
    if (m_proxy)
        return false;
    if (m_connection && m_connection->isConnecting())
        return true;
    return false;
}

void Protocol::send(const OutputMessagePtr& outputMessage, bool rawPacket)
{
    if (m_player) {
        m_player->onOutputPacket(outputMessage);
        return;
    }

    if (m_recorder) {
        m_recorder->addOutputPacket(outputMessage);
    }

    if (!rawPacket) {
        // encrypt
        if (m_xteaEncryptionEnabled)
            xteaEncrypt(outputMessage);

        // write checksum
        if (m_sequencedPackets)
            outputMessage->writeSequence(m_packetNumber++);
        else if (m_checksumEnabled)
            outputMessage->writeChecksum();

        // write message size
        outputMessage->writeMessageSize(m_bigPackets, m_scaledPacketSize);
    }

    if (m_proxy) {
        auto packet = std::make_shared<ProxyPacket>(outputMessage->getHeaderBuffer(), outputMessage->getWriteBuffer());
        g_proxy.send(m_proxy, packet);
        outputMessage->reset();
        return;
    }

    // send
    if (m_connection)
        m_connection->write(outputMessage->getHeaderBuffer(), outputMessage->getMessageSize());

    // reset message to allow reuse
    outputMessage->reset();
}

void Protocol::recv()
{
    if (m_player)
        return;

    if (m_proxy) {
        return;
    }

    m_inputMessage->reset();

    // first update message header size
    int headerSize = m_bigPackets ? 4 : 2; // 2 or 4 bytes for message size
    if (m_checksumEnabled)
        headerSize += 4; // 4 bytes for checksum
    if (m_xteaEncryptionEnabled)
        headerSize += m_bigPackets ? 4 : 2; // 2 or 4 bytes for XTEA encrypted message size
    m_inputMessage->setHeaderSize(headerSize);

    // read the first 2 bytes which contain the message size
    if (m_connection)
        m_connection->read(m_bigPackets ? 4 : 2, std::bind(&Protocol::internalRecvHeader, asProtocol(), std::placeholders::_1, std::placeholders::_2));
}

void Protocol::internalRecvHeader(uint8* buffer, uint32 size)
{
    // read message size
    m_inputMessage->fillBuffer(buffer, size);
    uint32 remainingSize = m_inputMessage->readSize(m_bigPackets);

    // Tibia 13.x+/crystalserver scales the ProtocolGame size header by 8 (the
    // wire value is (realSize - 4) / 8). Undo it to get the real body length.
    if (m_scaledPacketSize)
        remainingSize = remainingSize * 8 + 4;

    // read remaining message data
    if (m_connection)
        m_connection->read(remainingSize, std::bind(&Protocol::internalRecvData, asProtocol(), std::placeholders::_1, std::placeholders::_2));
}

void Protocol::internalRecvData(uint8* buffer, uint32 size)
{
    // process data only if really connected
    if (!isConnected()) {
        g_logger.traceError("received data while disconnected");
        return;
    }

    m_inputMessage->fillBuffer(buffer, size);

    bool decompress = false;
    if (m_sequencedPackets) {
        // crystalserver/Canary mark a compressed sequenced packet by setting the
        // high bit (1 << 31) of the sequence word: header = 0x80000000 | seq.
        // The low 31 bits are the sequence number. Test the compression bit, not
        // a >= 0xC0000000 threshold (which misses 0x80000001 = compressed seq 1).
        if ((m_inputMessage->getU32() & 0x80000000) != 0) {
            decompress = true;
        }
    } else if (m_checksumEnabled) {
        if (m_inputMessage->peekU32() == 0) { // compressed data
            m_inputMessage->getU32();
            decompress = true;
        } else if (!m_inputMessage->readChecksum()) {
            g_logger.traceError(stdext::format("got a network message with invalid checksum, size: %i", (int)m_inputMessage->getMessageSize()));
            return;
        }
    }

    if (m_xteaEncryptionEnabled) {
        if (!xteaDecrypt(m_inputMessage, decompress)) {
            g_logger.traceError("failed to decrypt message");
            return;
        }
    }

    // Only decompress packets the server actually compressed (high bit set in the
    // sequence word, captured in `decompress`). m_compression just means the
    // feature is enabled — using it here forced inflate on EVERY packet, breaking
    // the small uncompressed ones (zlib -3 on seq words 2,3,4,...).
    if (decompress) {
        m_inputMessage->addZlibFooter();
        // crystalserver/Canary compress each packet INDEPENDENTLY with libdeflate
        // (a self-contained raw-deflate block, BFINAL=1). So we must reset the
        // inflate stream for every packet: once a packet inflates to Z_STREAM_END,
        // a persistent zstream stays "finished" and every subsequent compressed
        // packet returns Z_STREAM_END with 0 output -> the whole packet (e.g. tile
        // updates that add stackpos-1 items) is silently dropped, which showed up as
        // "no thing at pos ... stackpos:2" on walk. inflateReset re-arms the stream.
        inflateReset(&m_zstream);
        m_zstream.next_in = m_inputMessage->getReadBuffer();
        m_zstream.next_out = m_zstreamBuffer.data();
        m_zstream.avail_in = m_inputMessage->getUnreadSize();
        m_zstream.avail_out = m_zstreamBuffer.size();
        int ret = inflate(&m_zstream, Z_SYNC_FLUSH);
        if (ret != Z_OK && ret != Z_STREAM_END) {
            g_logger.traceError(stdext::format("failed to decompress message (zlib %d)", ret));
            return;
        }
        int decryptedSize = m_zstreamBuffer.size() - m_zstream.avail_out;
        if (decryptedSize == 0) {
            g_logger.traceError(stdext::format("invalid size of decompressed message - %i", decryptedSize));
            return;
        }
        m_inputMessage->fillBuffer(m_zstreamBuffer.data(), decryptedSize);
        // The decompressed body was written at the CURRENT read position (past the
        // sequence word), so the message size must be anchored to that read offset,
        // not to getHeaderSize(). getHeaderSize() reports the size-header width (8),
        // which is one byte wider than the actual bytes consumed to reach the body
        // (the 4-byte size header is double-counted against the 4-byte sequence word
        // read inside internalRecvData). Using getHeaderSize() left getUnreadSize()
        // one byte too large, so after a packet decoded fully the parser saw 1 stray
        // trailing byte, read it as a bogus opcode (0xcd / 0x69) and threw
        // "InputMessage eof reached" -- which dropped the stackpos-1 tile items and
        // surfaced as "no thing at pos ... stackpos:2" on walk.
        const int bodyOffset = m_inputMessage->getReadPos() - (InputMessage::MAX_HEADER_SIZE - m_inputMessage->getHeaderSize());
        m_inputMessage->setMessageSize(bodyOffset + decryptedSize);
    }

    if (m_recorder) {
        m_recorder->addInputPacket(m_inputMessage);
    }
    onRecv(m_inputMessage);
}

void Protocol::generateXteaKey()
{
    std::mt19937 eng(std::time(NULL));
    std::uniform_int_distribution<uint32> unif(0, 0xFFFFFFFF);
    m_xteaKey[0] = unif(eng);
    m_xteaKey[1] = unif(eng);
    m_xteaKey[2] = unif(eng);
    m_xteaKey[3] = unif(eng);
}

void Protocol::setXteaKey(uint32 a, uint32 b, uint32 c, uint32 d)
{
    m_xteaKey[0] = a;
    m_xteaKey[1] = b;
    m_xteaKey[2] = c;
    m_xteaKey[3] = d;
}

std::vector<uint32> Protocol::getXteaKey()
{
    std::vector<uint32> xteaKey;
    xteaKey.resize(4);
    for (int i = 0; i < 4; ++i)
        xteaKey[i] = m_xteaKey[i];
    return xteaKey;
}

bool Protocol::xteaDecrypt(const InputMessagePtr& inputMessage, bool compressed)
{
    uint32 encryptedSize = inputMessage->getUnreadSize();
    if (encryptedSize % 8 != 0) {
        g_logger.traceError(stdext::format("invalid encrypted network message %i", (int)encryptedSize));
        return false;
    }

    uint32* buffer = (uint32*)(inputMessage->getReadBuffer());
    uint32_t readPos = 0;

    while (readPos < encryptedSize / 4) {
        uint32 v0 = buffer[readPos], v1 = buffer[readPos + 1];
        uint32 delta = 0x61C88647;
        uint32 sum = 0xC6EF3720;

        for (int32 i = 0; i < 32; i++) {
            v1 -= ((v0 << 4 ^ v0 >> 5) + v0) ^ (sum + m_xteaKey[sum >> 11 & 3]);
            sum += delta;
            v0 -= ((v1 << 4 ^ v1 >> 5) + v1) ^ (sum + m_xteaKey[sum & 3]);
        }
        buffer[readPos] = v0; buffer[readPos + 1] = v1;
        readPos = readPos + 2;
    }

    // crystalserver/Canary XTEA payload framing differs from legacy OTServ.
    // The server's writePaddingAmount() puts a single padding-count byte at the
    // FRONT of the encrypted block: [paddingAmount:1][payload][padding...]. On
    // decrypt we read that byte and the real payload length is
    // encryptedSize - 1 - paddingAmount. (Legacy OTServ instead prepends a
    // 2/4-byte message size — m_scaledPacketSize distinguishes the two.)
    if (m_scaledPacketSize) {
        // getU8() consumes the leading padding-count byte and advances the read
        // position (so getUnreadSize() already dropped that 1 byte). We only
        // need to trim the trailing XTEA padding from the total message size:
        // subtract paddingAmount, NOT 1 + paddingAmount, otherwise the payload
        // ends up 1 byte short and every parse hits "eof reached".
        uint8 paddingAmount = inputMessage->getU8();
        int realSize = (int)encryptedSize - 1 - (int)paddingAmount;
        if (realSize < 0 || realSize > (int)encryptedSize) {
            g_logger.traceError("invalid decrypted network message");
            return false;
        }
        inputMessage->setMessageSize(inputMessage->getMessageSize() - paddingAmount);
        return true;
    }

    // Legacy OTServ: the first field is the real message length.
    uint32 decryptedSize = m_bigPackets ? (inputMessage->getU32() + 4) : (inputMessage->getU16() + 2);
    int sizeDelta = decryptedSize - encryptedSize;
    if (sizeDelta > 0 || -sizeDelta > (int)encryptedSize) {
        g_logger.traceError("invalid decrypted network message");
        return false;
    }

    inputMessage->setMessageSize(inputMessage->getMessageSize() + sizeDelta);
    return true;
}

void Protocol::xteaEncrypt(const OutputMessagePtr& outputMessage)
{
    uint32 encryptedSize;
    uint32* buffer;

    if (m_sequencedPackets) {
        // crystalserver/Canary SEQUENCE-XTEA: the encrypted block is
        // [paddingCount U8][message body][padding], padded to a multiple of 8.
        // writePaddingAmount() prepends the count byte (at m_headerPos) and appends
        // the trailing padding; we then XTEA-encrypt the whole block starting at the
        // header position. The legacy OTServ layout (size field at front, zero pad at
        // end) made the server's XTEA_decrypt read a bogus padding size and silently
        // DROP every client->server packet (walk, ping, actions), so nothing worked.
        encryptedSize = outputMessage->writePaddingAmount();
        buffer = (uint32*)outputMessage->getHeaderBuffer();
    } else {
        // Legacy OTServ XTEA (pre-sequence): size field at front, zero padding at end.
        outputMessage->writeMessageSize(m_bigPackets);
        encryptedSize = outputMessage->getMessageSize();
        if ((encryptedSize % 8) != 0) {
            uint32 n = 8 - (encryptedSize % 8);
            outputMessage->addPaddingBytes(n);
            encryptedSize += n;
        }
        buffer = (uint32*)(outputMessage->getDataBuffer() - (m_bigPackets ? 4 : 2));
    }

    uint32_t readPos = 0;
    while (readPos < encryptedSize / 4) {
        uint32 v0 = buffer[readPos], v1 = buffer[readPos + 1];
        uint32 delta = 0x61C88647;
        uint32 sum = 0;

        for (int32 i = 0; i < 32; i++) {
            v0 += ((v1 << 4 ^ v1 >> 5) + v1) ^ (sum + m_xteaKey[sum & 3]);
            sum -= delta;
            v1 += ((v0 << 4 ^ v0 >> 5) + v0) ^ (sum + m_xteaKey[sum >> 11 & 3]);
        }
        buffer[readPos] = v0; buffer[readPos + 1] = v1;
        readPos = readPos + 2;
    }
}

void Protocol::onConnect()
{
    callLuaField("onConnect");
}

void Protocol::onRecv(const InputMessagePtr& inputMessage)
{
    callLuaField("onRecv", inputMessage);
}

void Protocol::onError(const boost::system::error_code& err)
{
    callLuaField("onError", err.message(), err.value());
    disconnect();
}

void Protocol::onPlayerPacket(const std::shared_ptr<std::vector<uint8_t>>& packet)
{
    if (m_disconnected)
        return;
    auto self(asProtocol());
    boost::asio::post(g_ioService, [&, self, packet] {
        if (m_disconnected)
            return;
        m_inputMessage->reset();

        m_inputMessage->setHeaderSize(0);
        m_inputMessage->fillBuffer(packet->data(), packet->size());
        m_inputMessage->setMessageSize(packet->size());
        onRecv(m_inputMessage);
    });
}

void Protocol::onProxyPacket(const std::shared_ptr<std::vector<uint8_t>>& packet)
{
    if (m_disconnected)
        return;
    auto self(asProtocol());
    boost::asio::post(g_ioService, [&, self, packet] {
        if (m_disconnected)
            return;
        m_inputMessage->reset();

        // first update message header size
        int headerSize = m_bigPackets ? 4 : 2; // 2 bytes for message size
        if (m_checksumEnabled)
            headerSize += 4; // 4 bytes for checksum
        if (m_xteaEncryptionEnabled)
            headerSize += m_bigPackets ? 4 : 2; // 2 bytes for XTEA encrypted message size
        m_inputMessage->setHeaderSize(headerSize);
        m_inputMessage->fillBuffer(packet->data(), m_bigPackets ? 4 : 2);
        m_inputMessage->readSize(m_bigPackets);
        internalRecvData(packet->data() + (m_bigPackets ? 4 : 2), packet->size() - (m_bigPackets ? 4 : 2));
    });
}

void Protocol::onLocalDisconnected(boost::system::error_code ec)
{
    if (m_disconnected)
        return;
    auto self(asProtocol());
    boost::asio::post(g_ioService, [&, self, ec] {
        if (m_disconnected)
            return;
        m_disconnected = true;
        onError(ec);
    });
}
