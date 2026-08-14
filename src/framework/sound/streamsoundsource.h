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

#ifdef FW_SOUND

#ifndef STREAMSOUNDSOURCE_H
#define STREAMSOUNDSOURCE_H

#include "soundsource.h"

class StreamSoundSource : public SoundSource
{
    enum {
        STREAM_BUFFER_SIZE = 1024 * 400,
        STREAM_FRAGMENTS = 4,
        STREAM_FRAGMENT_SIZE = STREAM_BUFFER_SIZE / STREAM_FRAGMENTS
    };

public:
    // DownMixMono averages both channels; Left/Right keep one and drop the other
    // (that pair exists for the linux stereo workaround in SoundManager).
    enum DownMix { NoDownMix, DownMixLeft, DownMixRight, DownMixMono };

    StreamSoundSource();
    virtual ~StreamSoundSource();

    void play();
    void stop();

    bool isPlaying() { return m_playing; }

    void setSoundFile(const SoundFilePtr& soundFile);

    // AL_LOOPING is invalid on a source with queued buffers, so a stream loops by
    // rewinding its file in update() instead of through the base implementation.
    void setLooping(bool looping) override { m_looping = looping; }

    void downMix(DownMix downMix);

    void update();

private:
    void queueBuffers();
    void unqueueBuffers();
    bool fillBufferAndQueue(uint buffer);

    SoundFilePtr m_soundFile;
    std::array<SoundBufferPtr,STREAM_FRAGMENTS> m_buffers;
    DownMix m_downMix;
    stdext::boolean<false> m_looping;
    stdext::boolean<false> m_playing;
    stdext::boolean<false> m_eof;
    stdext::boolean<false> m_waitingFile;
};

#endif

#endif
