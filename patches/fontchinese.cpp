/* ScummVM - Graphic Adventure Engine
 *
 * ScummVM is the legal property of its developers, whose names
 * are too numerous to list here. Please refer to the COPYRIGHT
 * file distributed with this source distribution.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

// Diagnostic switch: SCI_CHT_NOHIRES=1 forces the low-res (visual-plane) path so we can tell
// "the hi-res glyph is wrong" apart from "something repaints over the display buffer".
#define FORBIDDEN_SYMBOL_EXCEPTION_getenv

#include "common/file.h"
#include "graphics/big5.h"

#include "sci/sci.h"
#include "sci/graphics/screen.h"
#include "sci/graphics/fontchinese.h"

namespace Sci {

// Big5 font data file shipped alongside the game (part of the CHT patch).
static const char *kChineseFontFile = "camelot_big5.fnt";
// Layout advance per Chinese char (logical 320x200 px). Reduced from the Big5Font native
// 16px so dialogue fits KQ4's compact portrait/message boxes without overflowing (issue #1).
// Low-res advance (menu path): the built-in Graphics::Big5Font glyph is a fixed 16px wide,
// so the cell must stay wide enough not to clip it. Menu text uses this.
static const int kBig5Width = 16;
// Hi-res advance (dialogue path): the 20px hi-res glyph box exactly fills the 20px display
// advance (2 * kBig5WidthHi), so characters pack edge-to-edge — dense per line but still big
// enough to read (validated in leisure_suit_2; player feedback: 字太大/太鬆/台詞被截斷).
static const int kBig5WidthHi = 12;

// Hi-res Big5 font (own format, bake_hires_font.py): kHiW-px-wide, kHiH-row glyphs drawn
// straight onto the 640x400 display buffer for sharp strokes under ZH_TWN upscaling.
// kHiW <= kBig5WidthHi*2 (=24) so glyphs never bleed into the next cell; row stride is
// ceil(kHiW/8) bytes, so kHiW need not be a multiple of 8.
static const char *kChineseHiResFontFile = "camelot_big5_hi.fnt";
static const int kHiW = 24;
static const int kHiH = 24;

// True when the current draw/measure should take the hi-res dialogue path (upscaled display,
// not a menu). Width metrics and drawing must agree on this so wrapping matches rendering.
bool GfxFontChinese::useHiRes() const {
	static const int forceLow = getenv("SCI_CHT_NOHIRES") ? 1 : 0;
	if (forceLow)
		return false;
	return !_screen->menuTextActive() && _screen->getDisplayWidth() > _screen->getWidth();
}

GfxFontChinese::GfxFontChinese(ResourceManager *resMan, GfxScreen *screen, GuiResourceId resourceId)
	: _screen(screen), _resourceId(resourceId), _big5(nullptr), _big5Height(14), _big5GlyphH(15) {
	// Original SCI font for single-byte (ASCII / control) glyphs.
	_asciiFont = new GfxFontFromResource(resMan, screen, resourceId);

	Common::File fontFile;
	if (fontFile.open(kChineseFontFile)) {
		_big5 = new Graphics::Big5Font();
		_big5->loadPrefixedRaw(fontFile, _big5Height);
		_big5Height = _big5->getFontHeight();
		// 字模的真實高度，繪製用。_big5Height 之後會被 cap 成「行距」，兩者不是同一件事
		// ——低解析路徑先前拿被 cap 過的行距去畫，等於把字底部切掉 2 列。
		_big5GlyphH = _big5Height;
	} else {
		warning("GfxFontChinese: could not open '%s'; Chinese glyphs will be blank", kChineseFontFile);
	}
	// Line-height metric for layout (getHeight), in the game's logical 320x200 coords; the
	// hi-res path draws at top*2, so one unit here == 2 display rows.
	//
	// Capped below the native glyph height so lines pack tighter and boxes hold more text
	// (issue #1: 對話後面被截斷). But it must stay strictly above kHiH/2: at exactly 12 the
	// line pitch (24px) equals the glyph height (24px), leaving zero gap — and because the
	// 倚天 24x24 cell has no built-in margin, adjacent lines' strokes touch and the text turns
	// into a smear. Only visible on multi-line borderless text (the intro crawl over the
	// castle); framed dialogue boxes are short enough that it reads as merely tight.
	// 13 => 26px pitch, 2px of air. 見 CONTEXT.md「開場字幕行距」。
	if (_big5Height > 13)
		_big5Height = 13;

	_hiW = kHiW;
	_hiH = kHiH;
	loadHiResFont();
}

// Load the hi-res Big5 font: repeated { big-endian Big5 code (uint16), _hiH*(_hiW/8) glyph
// bytes }, terminated by 0xFFFF. Keeps a code->offset index into the flat _hiData blob.
// Missing file just means we fall back to the low-res Big5 path (no hi-res sharpening).
bool GfxFontChinese::loadHiResFont() {
	Common::File f;
	if (!f.open(kChineseHiResFontFile))
		return false;
	const uint bytesPerGlyph = _hiH * ((_hiW + 7) / 8);
	while (!f.eos()) {
		uint16 code = f.readUint16BE();
		if (f.eos() || code == 0xFFFF)
			break;
		uint32 offset = _hiData.size();
		_hiData.resize(offset + bytesPerGlyph);
		if (f.read(&_hiData[offset], bytesPerGlyph) != bytesPerGlyph)
			break;
		_hiIndex[code] = offset;
	}
	return !_hiIndex.empty();
}

GfxFontChinese::~GfxFontChinese() {
	delete _big5;
	delete _asciiFont;
}

GuiResourceId GfxFontChinese::getResourceId() {
	return _resourceId;
}

byte GfxFontChinese::getHeight() {
	byte asciiHeight = _asciiFont->getHeight();
	return MAX<byte>(asciiHeight, (byte)_big5Height);
}

// text16 tests this on the first (lead) byte before combining the pair.
bool GfxFontChinese::isDoubleByte(uint16 chr) {
	return (chr >= 0x81) && (chr <= 0xFE);
}

byte GfxFontChinese::getCharWidth(uint16 chr) {
	// chr may arrive either as a bare lead byte (during width scans) or as a
	// combined lead|(trail<<8) value (during drawing). Both mean a Big5 char.
	// The advance must match the path draw() will take (same useHiRes() gate) so that
	// line-wrapping (GetLongest) and rendering agree — else text overflows its box.
	if (chr > 0xFF || isDoubleByte(chr))
		return useHiRes() ? kBig5WidthHi : kBig5Width;
	return _asciiFont->getCharWidth(chr);
}

byte GfxFontChinese::getCharHeight(uint16 chr) {
	if (chr > 0xFF || isDoubleByte(chr))
		return (byte)_big5Height;
	return _asciiFont->getHeight();
}

void GfxFontChinese::draw(uint16 chr, int16 top, int16 left, byte color, bool greyedOutput) {
	// Single-byte: delegate to the original SCI font (keeps ASCII pixel-identical).
	if (chr <= 0xFF) {
		_asciiFont->draw(chr, top, left, color, greyedOutput);
		return;
	}

	// Double-byte: chr == lead | (trail << 8); Big5Font wants (lead << 8) | trail.
	uint16 point = ((chr & 0xFF) << 8) | (chr >> 8);

	// Hi-res path: when ZH_TWN runs upscaled (640x400 display) and we have a hi-res glyph,
	// draw sharp 32xN strokes directly onto the display instead of the blocky 2x low-res.
	// Skipped for menu text (bar + dropdown): the hi-res path writes only to the display
	// buffer, but menu highlight inverts the visual buffer + re-upscales, which would wipe
	// hi-res glyphs to black-on-black. Low-res writes the visual buffer too, so it inverts.
	if (useHiRes() && _hiIndex.contains(point)) {
		drawHiRes(point, top, left, color);
		return;
	}

	byte glyph[kBig5Width * 16];
	memset(glyph, 0, sizeof(glyph));
	bool drawn = false;
	if (_big5)
		drawn = _big5->drawBig5Char(glyph, point, kBig5Width, _big5GlyphH, kBig5Width,
		                            /*color*/ 1, /*outlineColor*/ 0, /*outline*/ false, /*bpp*/ 1);
	if (!drawn) {
		// Fall back to a placeholder so missing glyphs are visible, not silent.
		_asciiFont->draw('?', top, left, color, greyedOutput);
		return;
	}

	uint16 screenWidth = _screen->fontIsUpscaled() ? _screen->getDisplayWidth() : _screen->getWidth();
	uint16 screenHeight = _screen->fontIsUpscaled() ? _screen->getDisplayHeight() : _screen->getHeight();

	// [HARD] 這條路徑**不**做膨脹。膨脹是給 hi-res 外框字用的（SCI 兩趟疊畫，黑色那趟
	// 要比白色本體大一圈才不會被蓋掉）。低解析只走選單，那是單純的黑字白底、沒有第二趟；
	// 在這裡膨脹會讓 16x15 的中文字模每邊各胖 1px，選單列裡整排字糊成一團黑塊
	// （github issue #1 的第一張截圖）。
	for (int y = 0; y < _big5GlyphH; y++) {
		for (int x = 0; x < kBig5Width; x++) {
			if (!glyph[y * kBig5Width + x])
				continue;
			const int screenX = left + x;
			const int screenY = top + y;
			if (0 <= screenX && screenX < screenWidth && 0 <= screenY && screenY < screenHeight)
				_screen->putFontPixel(top, screenX, y, color);
		}
	}
}

// Draw a hi-res Big5 glyph directly onto the 640x400 display buffer. The game positions
// text in logical 320x200 coords, so we map (left, top) -> (left*2, top*2) on the display
// and toggle _fontIsUpscaled so putFontPixel writes straight to the display (no further
// nearest-scale), giving sharp 32xN strokes. ASCII glyphs are unaffected (they draw with
// _fontIsUpscaled == false and get the normal 2x upscale, matching the game art).
void GfxFontChinese::drawHiRes(uint16 point, int16 top, int16 left, byte color) {
	Common::HashMap<uint16, uint32>::const_iterator it = _hiIndex.find(point);
	if (it == _hiIndex.end())
		return;
	const byte *bmp = &_hiData[it->_value];
	const int rowBytes = (_hiW + 7) / 8;
	// Centre the hi-res glyph within the 2x hi-res advance cell (24px glyph in a 24px cell
	// => flush, no loose gap).
	const int dispLeft = left * 2 + (2 * kBig5WidthHi - _hiW) / 2;
	const int dispTop = top * 2;
	const int dispW = _screen->getDisplayWidth();
	const int dispH = _screen->getDisplayHeight();

	// [HARD] SCI 用「兩個字型疊畫」做外框字：先用實心遮罩字型（本作是 font.104）畫黑色，
	// 再用細字型（font.103）畫白色。中文若兩趟都畫同一套 Big5 字模，白色會**完全蓋掉**黑色
	// → 外框消失。白字畫在白雲上就等於整段看不見（本作開場旁白就是這樣消失的，
	// 而且字模本身是好的，看起來只像「字太淡」，很容易誤判成字型烘壞）。
	// 修法：黑色那一趟把字模膨脹一圈，讓它比白色本體大，外框就回來了。
	const bool dilate = (color == 0);

	const bool savedUpscaled = _screen->fontIsUpscaled();
	_screen->setFontIsUpscaled(true);
	for (int gy = 0; gy < _hiH; gy++) {
		const int dispY = dispTop + gy;
		if (dispY < 0 || dispY >= dispH)
			continue;
		for (int gx = 0; gx < _hiW; gx++) {
			if (!(bmp[gy * rowBytes + (gx >> 3)] & (0x80 >> (gx & 7))))
				continue;
			const int dispX = dispLeft + gx;
			if (dispX < 0 || dispX >= dispW)
				continue;
			if (dilate) {
				// Fatten the black pass by one pixel so the white pass cannot cover it.
				// A plus shape (N/S/E/W) leaves the diagonals bare, and CJK is full of
				// 撇／捺 strokes running diagonally — over a light background (the intro
				// crawl across sky and cloud) the outline breaks up along exactly those
				// strokes and the text washes out. The full 3x3 keeps it continuous.
				// SCI_CHT_OUTLINE=cross reverts to the plus shape for A/B comparison.
				static const int kCross[5][2] = {{0, 0}, {-1, 0}, {1, 0}, {0, -1}, {0, 1}};
				static const int kBox[9][2] = {{0, 0}, {-1, 0}, {1, 0}, {0, -1}, {0, 1},
				                               {-1, -1}, {1, -1}, {-1, 1}, {1, 1}};
				const char *outlineMode = getenv("SCI_CHT_OUTLINE");
				const bool cross = outlineMode && !strcmp(outlineMode, "cross");
				const int n = cross ? 5 : 9;
				for (int i = 0; i < n; i++) {
					const int px = dispX + (cross ? kCross[i][0] : kBox[i][0]);
					const int py = dispY + (cross ? kCross[i][1] : kBox[i][1]);
					if (px < 0 || px >= dispW || py < 0 || py >= dispH)
						continue;
					_screen->putFontPixel(dispTop, px, py - dispTop, color);
				}
			} else {
				_screen->putFontPixel(dispTop, dispX, gy, color);
			}
		}
	}
	_screen->setFontIsUpscaled(savedUpscaled);
}

} // End of namespace Sci
