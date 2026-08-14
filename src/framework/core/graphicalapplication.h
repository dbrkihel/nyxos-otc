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


#ifndef GRAPHICALAPPLICATION_H
#define GRAPHICALAPPLICATION_H

#include "application.h"
#include <atomic>
#include <framework/graphics/declarations.h>
#include <framework/core/inputevent.h>
#include <framework/core/adaptiverenderer.h>
#include <framework/util/framecounter.h>

class GraphicalApplication : public Application
{
public:
    void init(std::vector<std::string>& args);
    void deinit();
    void terminate();
    void run();
    void poll();
    void pollGraphics();
    void close();

    bool willRepaint() { return m_mustRepaint; }
    void repaint() { m_mustRepaint = true; }

    // UI framebuffer cache: rasterize the after-map UI at most ~60fps into a
    // framebuffer and blit it every frame, instead of redrawing the whole UI at
    // the full render rate. Toggleable at runtime (g_app.setCacheUI) for A/B.
    void setCacheUI(bool v) { m_cacheUI = v; if (v) m_mustRepaint = true; } // refresh now on enable
    bool isCacheUI() { return m_cacheUI; }

    void setMaxFps(int maxFps) { m_maxFps = maxFps; }
    int getMaxFps() { return m_maxFps; }
    int getFps() { return m_graphicsFrames.getFps(); }
    int getGraphicsFps() { return m_graphicsFrames.getFps(); }
    int getProcessingFps() { return m_processingFrames.getFps(); }

    bool isOnInputEvent() { return m_onInputEvent; }

    int getIteration() {
        return m_iteration;
    }

    void doScreenshot(std::string file);
    void scaleUp();
    void scaleDown();
    void scale(float value);
    void setSmooth(bool value);

    void doMapScreenshot(std::string fileName);

protected:
    void resize(const Size& size);
    void inputEvent(InputEvent event);

private:
    int m_iteration = 0;
    std::atomic<float> m_scaling = 1.0;
    std::atomic<float> m_lastScaling = 1.0;
    std::atomic_int m_maxFps = 100;
    std::atomic_bool m_cacheUI = true;
    std::atomic_bool m_mustRepaint = false; // atomic: set on worker thread, read+cleared on render thread
    stdext::boolean<false> m_onInputEvent;
    FrameBufferPtr m_framebuffer, m_mapFramebuffer, m_uiFramebuffer;
    FrameCounter m_graphicsFrames;
    FrameCounter m_processingFrames;
    stdext::timer m_windowPollTimer;
};

extern GraphicalApplication g_app;

#endif
