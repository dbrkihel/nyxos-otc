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

#ifndef MOUSE_H
#define MOUSE_H

#include <framework/global.h>

class Mouse
{
public:
    void init();
    void terminate();

    void loadCursors(std::string filename);
    void addCursor(const std::string& name, const std::string& file, const Point& hotSpot);
    void pushCursor(const std::string& name);
    void popCursor(const std::string& name);
    bool isCursorChanged();
    bool isPressed(Fw::MouseButton mouseButton);

    // "Use Native Mouse Cursor" option: when enabled, keep the OS native cursor and
    // ignore every custom cursor swap (item hover 'target', text edit, splitters,
    // resize borders, ...). The cursor stack is still tracked so toggling the option
    // off restores the correct custom cursor.
    void setNativeCursor(bool enable);
    bool isNativeCursor() { return m_nativeCursor; }

private:
    // Apply the topmost stacked cursor that may show under the current mode.
    void applyTopCursor();
    // Whether a cursor id stays custom while "Use Native Mouse Cursor" is on.
    bool isAllowedInNativeMode(int cursorId);

    std::map<std::string, int> m_cursors;
    std::deque<int> m_cursorStack;
    std::mutex m_mutex;
    bool m_nativeCursor = false;
};

extern Mouse g_mouse;

#endif
