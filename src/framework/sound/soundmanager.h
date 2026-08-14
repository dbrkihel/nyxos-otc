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

#ifndef SOUNDMANAGER_H
#define SOUNDMANAGER_H

#include "declarations.h"
#include "soundchannel.h"

//@bindsingleton g_sounds
class SoundManager
{
    enum {
        MAX_CACHE_SIZE = 100000,
        POLL_DELAY = 100
    };
public:
    void init();
    void terminate();
    void poll();

    void setAudioEnabled(bool enable);
    bool isAudioEnabled() { return m_device && m_context && m_audioEnabled ; }
    void enableAudio() { setAudioEnabled(true); }
    void disableAudio() { setAudioEnabled(true); }
    void stopAll();

    void preload(std::string filename);
    SoundSourcePtr play(std::string filename, float fadetime = 0, float gain = 0);
    // Looping mono stream the caller places and fades itself. OpenAL ignores
    // AL_POSITION on stereo sources, and every bank file is stereo, so the
    // stream is downmixed before its first buffer is queued.
    SoundSourcePtr playPositioned(std::string filename, float gain, float x, float y);
    SoundChannelPtr getChannel(int channel);

    std::string resolveSoundFile(std::string file);
    void ensureContext();

    // Output device selection. An empty name means "let OpenAL pick", which is
    // what the official client calls "(auto-select)".
    std::vector<std::string> getDeviceNames();
    std::string getCurrentDevice() { return m_deviceName; }
    bool setDevice(const std::string& name);

private:
    SoundSourcePtr createSoundSource(const std::string& filename);
    bool openDevice(const std::string& name);
    void closeDevice();

    ALCdevice *m_device;
    ALCcontext *m_context;
    std::string m_deviceName;

    std::map<StreamSoundSourcePtr, std::shared_future<SoundFilePtr>> m_streamFiles;
    std::unordered_map<std::string, SoundBufferPtr> m_buffers;
    std::vector<SoundSourcePtr> m_sources;
    stdext::boolean<true> m_audioEnabled;
    std::unordered_map<int, SoundChannelPtr> m_channels;
};

extern SoundManager g_sounds;

#endif

#endif