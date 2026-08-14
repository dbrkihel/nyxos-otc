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

#ifndef FONTMANAGER_H
#define FONTMANAGER_H

#include "bitmapfont.h"

//@bindsingleton g_fonts
class FontManager
{
public:
    FontManager();

    void terminate();
    void clearFonts();

    void importFont(std::string file);

    bool fontExists(const std::string& fontName);
    BitmapFontPtr getFont(const std::string& fontName);
    BitmapFontPtr getDefaultFont() { return m_defaultFont; }

    void setDefaultFont(const std::string& fontName) { m_defaultFont = getFont(fontName); }

    // Inline text images (see bitmapfont.h). Register a byte code (1..255, must
    // be a control byte < 32 so it never collides with real text) to draw a
    // sub-rect of an image file wherever that byte appears in any text. The
    // store description uses this to render its {info}/{character}/... icons.
    void registerInlineImage(int code, const std::string& file, int srcX, int srcY, int srcW, int srcH, int yOffset);
    const InlineTextImage* getInlineImage(int code) const {
        return (code > 0 && code < 256 && m_inlineImages[code].width > 0) ? &m_inlineImages[code] : nullptr;
    }
    bool hasInlineImages() const { return m_inlineImageCount > 0; }

    // Style fonts (see bitmapfont.h StyledTextRun). Register a control byte that,
    // when found in text, switches subsequent glyphs to an alternate font (bold,
    // italic, ...). An empty fontName registers a "reset" byte that returns to the
    // text's base font. Used by the store to render <i>/<b> description segments.
    void registerStyleFont(int code, const std::string& fontName);
    const BitmapFontPtr& getStyleFont(int code) const;
    bool isStyleReset(int code) const { return code > 0 && code < 256 && m_styleReset[code]; }
    bool hasStyleFonts() const { return m_styleCount > 0; }

private:
    std::vector<BitmapFontPtr> m_fonts;
    BitmapFontPtr m_defaultFont;
    InlineTextImage m_inlineImages[256];
    int m_inlineImageCount = 0;
    BitmapFontPtr m_styleFonts[256];
    bool m_styleReset[256] = {};
    int m_styleCount = 0;
};

extern FontManager g_fonts;

#endif
