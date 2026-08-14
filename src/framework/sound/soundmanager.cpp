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

#include "soundmanager.h"
#include "soundsource.h"
#include "soundbuffer.h"
#include "soundfile.h"
#include "streamsoundsource.h"
#include "combinedsoundsource.h"

#include <framework/core/clock.h>
#include <framework/core/eventdispatcher.h>
#include <framework/core/resourcemanager.h>
#include <framework/core/asyncdispatcher.h>
#include <thread>
#include <framework/util/stats.h>

SoundManager g_sounds;

bool SoundManager::openDevice(const std::string& name)
{
    m_device = alcOpenDevice(name.empty() ? NULL : name.c_str());
    if(!m_device) {
        g_logger.error(stdext::format("unable to open audio device '%s'", name.empty() ? "(auto-select)" : name));
        return false;
    }

    m_context = alcCreateContext(m_device, NULL);
    if(!m_context) {
        g_logger.error(stdext::format("unable to create audio context: %s", alcGetString(m_device, alcGetError(m_device))));
        closeDevice();
        return false;
    }

    if(alcMakeContextCurrent(m_context) != ALC_TRUE) {
        g_logger.error(stdext::format("unable to make context current: %s", alcGetString(m_device, alcGetError(m_device))));
        closeDevice();
        return false;
    }

    m_deviceName = name;
    return true;
}

void SoundManager::closeDevice()
{
    alcMakeContextCurrent(nullptr);

    if(m_context) {
        alcDestroyContext(m_context);
        m_context = nullptr;
    }

    if(m_device) {
        alcCloseDevice(m_device);
        m_device = nullptr;
    }
}

void SoundManager::init()
{
    openDevice("");
}

// ALC_ALL_DEVICES_SPECIFIER is a run of NUL-terminated names ended by an empty
// one. Falls back to the basic list when the enumerate-all extension is absent.
std::vector<std::string> SoundManager::getDeviceNames()
{
    std::vector<std::string> names;

    const ALCchar* list = nullptr;
    if(alcIsExtensionPresent(nullptr, "ALC_ENUMERATE_ALL_EXT") == ALC_TRUE)
        list = alcGetString(nullptr, ALC_ALL_DEVICES_SPECIFIER);
    else if(alcIsExtensionPresent(nullptr, "ALC_ENUMERATION_EXT") == ALC_TRUE)
        list = alcGetString(nullptr, ALC_DEVICE_SPECIFIER);

    while(list && *list) {
        names.emplace_back(list);
        list += names.back().size() + 1;
    }
    return names;
}

// Everything buffered lives on the old context, so the caches go with it and a
// new device starts clean. Channels keep their gain because they are Lua-side.
bool SoundManager::setDevice(const std::string& name)
{
    if(name == m_deviceName)
        return true;

    const std::string previous = m_deviceName;

    stopAll();
    m_streamFiles.clear();
    m_sources.clear();
    m_buffers.clear();
    closeDevice();

    if(openDevice(name))
        return true;

    // Never leave the client mute because a device vanished: fall back to what
    // worked before, and to auto-select if even that is gone now.
    if(!openDevice(previous))
        openDevice("");
    return false;
}

void SoundManager::terminate()
{
    ensureContext();

    for(auto it = m_streamFiles.begin(); it != m_streamFiles.end();++it) {
        auto& future = it->second;
        future.wait();
    }
    m_streamFiles.clear();

    m_sources.clear();
    m_buffers.clear();
    m_channels.clear();

    m_audioEnabled = false;

    closeDevice();
}

void SoundManager::poll()
{
    AutoStat s(STATS_MAIN, "PollSounds");

    static ticks_t lastUpdate = 0;
    ticks_t now = g_clock.millis();

    if(now - lastUpdate < POLL_DELAY)
        return;

    lastUpdate = now;

    ensureContext();

    for(auto it = m_streamFiles.begin(); it != m_streamFiles.end();) {
        StreamSoundSourcePtr source = it->first;
        auto& future = it->second;

        if(future.valid()) {
            SoundFilePtr sound = future.get();
            if(sound)
                source->setSoundFile(sound);
            else
                source->stop();
            it = m_streamFiles.erase(it);
        } else {
            ++it;
        }
    }

    for(auto it = m_sources.begin(); it != m_sources.end();) {
        SoundSourcePtr source = *it;

        source->update();

        if(!source->isPlaying())
            it = m_sources.erase(it);
        else
            ++it;
    }

    for(auto it : m_channels) {
        it.second->update();
    }

    if(m_context) {
        alcProcessContext(m_context);
    }
}

void SoundManager::setAudioEnabled(bool enable)
{
    if(m_audioEnabled == enable)
        return;

    m_audioEnabled = enable;
    if(!enable) {
        ensureContext();
        for(const SoundSourcePtr& source : m_sources) {
            source->stop();
        }
    }
}

void SoundManager::preload(std::string filename)
{
    filename = resolveSoundFile(filename);

    auto it = m_buffers.find(filename);
    if(it != m_buffers.end())
        return;

    ensureContext();
    SoundFilePtr soundFile = SoundFile::loadSoundFile(filename);

    // only keep small files
    if(!soundFile || soundFile->getSize() > MAX_CACHE_SIZE)
        return;

    SoundBufferPtr buffer = std::make_shared<SoundBuffer>();
    if(buffer->fillBuffer(soundFile))
        m_buffers[filename] = buffer;
}

SoundSourcePtr SoundManager::play(std::string filename, float fadetime, float gain)
{
    if(!m_audioEnabled)
        return nullptr;

    ensureContext();

    filename = resolveSoundFile(filename);
    SoundSourcePtr soundSource = createSoundSource(filename);
    if(!soundSource) {
        g_logger.error(stdext::format("unable to play '%s'", filename));
        return nullptr;
    }

    soundSource->setName(filename);
    soundSource->setRelative(true);
    soundSource->setGain(gain);

    if(fadetime > 0)
        soundSource->setFading(StreamSoundSource::FadingOn, fadetime);

    soundSource->play();

    m_sources.push_back(soundSource);

    return soundSource;
}

SoundSourcePtr SoundManager::playPositioned(std::string filename, float gain, float x, float y)
{
    if(!m_audioEnabled)
        return nullptr;

    ensureContext();
    filename = resolveSoundFile(filename);

    // Built here rather than through createSoundSource: the downmix has to be set
    // before play() queues the first buffer, or the format would change mid-stream.
    auto streamSource = std::make_shared<StreamSoundSource>();
    streamSource->downMix(StreamSoundSource::DownMixMono);
    m_streamFiles[streamSource] = g_asyncDispatcher.schedule([=]() -> SoundFilePtr {
        try {
            return SoundFile::loadSoundFile(filename);
        } catch(std::exception& e) {
            g_logger.error(e.what());
            return nullptr;
        }
    });

    const SoundSourcePtr source = streamSource;
    source->setName(filename);
    source->setRelative(true);
    source->setLooping(true);
    source->setGain(gain);
    source->setPanning(x, y);
    source->play();

    m_sources.push_back(source);
    return source;
}

SoundChannelPtr SoundManager::getChannel(int channel)
{
    ensureContext();
    if(!m_channels[channel])
        m_channels[channel] = std::make_shared<SoundChannel>(channel);
    return m_channels[channel];
}

void SoundManager::stopAll()
{
    ensureContext();
    for(const SoundSourcePtr& source : m_sources) {
        source->stop();
    }

    for(auto it : m_channels) {
        it.second->stop();
    }
}

SoundSourcePtr SoundManager::createSoundSource(const std::string& filename)
{
    SoundSourcePtr source;

    try {
        auto it = m_buffers.find(filename);
        if(it != m_buffers.end()) {
            source = std::make_shared<SoundSource>();
            source->setBuffer(it->second);
        } else {
#if defined __linux && !defined OPENGL_ES
            // due to OpenAL implementation bug, stereo buffers are always downmixed to mono on linux systems
            // this is hack to work around the issue
            // solution taken from http://opensource.creative.com/pipermail/openal/2007-April/010355.html
            auto combinedSource = std::make_shared<CombinedSoundSource>();
            StreamSoundSourcePtr streamSource;

            streamSource = std::make_shared<StreamSoundSource>();
            streamSource->downMix(StreamSoundSource::DownMixLeft);
            streamSource->setRelative(true);
            streamSource->setPosition(Point(-128, 0));
            combinedSource->addSource(streamSource);
            m_streamFiles[streamSource] = g_asyncDispatcher.schedule([=]() -> SoundFilePtr {
                stdext::timer a;
                try {
                    return SoundFile::loadSoundFile(filename);
                } catch(std::exception& e) {
                    g_logger.error(e.what());
                    return nullptr;
                }
            });

            streamSource = std::make_shared<StreamSoundSource>();
            streamSource->downMix(StreamSoundSource::DownMixRight);
            streamSource->setRelative(true);
            streamSource->setPosition(Point(128,0));
            combinedSource->addSource(streamSource);
            m_streamFiles[streamSource] = g_asyncDispatcher.schedule([=]() -> SoundFilePtr {
                try {
                    return SoundFile::loadSoundFile(filename);
                } catch(std::exception& e) {
                    g_logger.error(e.what());
                    return nullptr;
                }
            });

            source = combinedSource;
#else
            auto streamSource = std::make_shared<StreamSoundSource>();
            m_streamFiles[streamSource] = g_asyncDispatcher.schedule([=]() -> SoundFilePtr {
                try {
                    return SoundFile::loadSoundFile(filename);
                } catch(std::exception& e) {
                    g_logger.error(e.what());
                    return nullptr;
                }
            });
            source = streamSource;
#endif
        }
    } catch(std::exception& e) {
        g_logger.error(stdext::format("failed to load sound source: '%s'", e.what()));
        return nullptr;
    }

    return source;
}

std::string SoundManager::resolveSoundFile(std::string file)
{
    // default to .ogg, but honor an explicit .wav so short PCM SFX work too
    if(!g_resources.isFileType(file, "ogg") && !g_resources.isFileType(file, "wav"))
        file = g_resources.guessFilePath(file, "ogg");
    file = g_resources.resolvePath(file);
    return file;
}

void SoundManager::ensureContext()
{
    if(m_context)
        alcMakeContextCurrent(m_context);
}

#endif