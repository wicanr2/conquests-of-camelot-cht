#!/usr/bin/env python3
"""用倚天點陣字烘標題疊圖 `.ovl`（SCI 格式）。

為什麼不用 TTF 或設計稿：標題疊圖若用另一套字型，會跟遊戲內文字明顯不同調。
直接拿 `STDFONT.15` 的字模加描邊，跟內文是同一套字形。

輸出格式（對齊 paint16.cpp 的 drawChtTitleOverlay）：
    LE u16 w, h, x, y   ← 座標是**邏輯 320x200**，不是 display 640x400
    然後 w*h bytes 的 EGA 調色盤索引，0xFF = 透明

[HARD] SCI 低解析路徑的 display 是 320x200。座標用 640x400 算會被 guard 判越界，
**靜默不疊、畫面上什麼都沒有卻不報錯**。

EGA 16 色索引：0 黑 1 藍 2 綠 3 青 4 紅 5 洋紅 6 棕 7 淺灰
              8 深灰 9 亮藍 10 亮綠 11 亮青 12 亮紅 13 亮洋紅 14 黃 15 白

用法：build_title_overlay_eten.py <輸出.ovl> <文字> [--x N] [--y N]
                                  [--fg 14] [--outline 4] [--std PATH] [--spc PATH]
"""
import sys, os, struct, argparse

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from eten_font import EtenFont

TRANSPARENT = 0xFF


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("out")
    ap.add_argument("text")
    ap.add_argument("--x", type=int, default=-1, help="邏輯 x（-1 = 水平置中於 320）")
    ap.add_argument("--y", type=int, default=1)
    ap.add_argument("--fg", type=int, default=14, help="字色 EGA 索引（預設黃）")
    ap.add_argument("--outline", type=int, default=4, help="描邊 EGA 索引（預設暗紅），-1 = 不描邊")
    ap.add_argument("--std", default="art/fonts/STDFONT.15")
    ap.add_argument("--spc", default="art/fonts/SPCFONT.15")
    a = ap.parse_args()

    eten = EtenFont(a.std, a.spc, 15)
    chars = list(a.text)
    cw, ch = 16, 15
    pad = 1 if a.outline >= 0 else 0
    w = len(chars) * cw + pad * 2
    h = ch + pad * 2
    buf = bytearray([TRANSPARENT] * (w * h))

    def put(x, y, idx):
        if 0 <= x < w and 0 <= y < h:
            buf[y * w + x] = idx

    # 先鋪描邊（八方向），再鋪字身，字身才不會被描邊吃掉
    for phase in (("outline", a.outline), ("fg", a.fg)):
        kind, color = phase
        if kind == "outline" and color < 0:
            continue
        for ci, cch in enumerate(chars):
            g = eten.glyph(cch)
            if g is None:
                sys.stderr.write(f"WARN 倚天字庫查無「{cch}」\n")
                continue
            for gy in range(ch):
                for gx in range(cw):
                    if not (g[gy * 2 + (gx >> 3)] & (0x80 >> (gx & 7))):
                        continue
                    bx, by = pad + ci * cw + gx, pad + gy
                    if kind == "outline":
                        for oy in (-1, 0, 1):
                            for ox in (-1, 0, 1):
                                put(bx + ox, by + oy, color)
                    else:
                        put(bx, by, color)

    x = (320 - w) // 2 if a.x < 0 else a.x
    with open(a.out, "wb") as f:
        f.write(struct.pack("<HHHH", w, h, x, a.y))
        f.write(bytes(buf))
    solid = sum(1 for b in buf if b != TRANSPARENT)
    print(f"{a.out}: {w}x{h} @({x},{a.y})，{len(chars)} 字，{solid} 個不透明像素")
    # ASCII 預覽，確認字形沒有錯位
    for y in range(h):
        print("  " + "".join("#" if buf[y * w + x2] == a.fg else
                             ("+" if buf[y * w + x2] != TRANSPARENT else ".")
                             for x2 in range(w)))


if __name__ == "__main__":
    main()
