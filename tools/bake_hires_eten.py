#!/usr/bin/env python3
"""烘 hi-res (24×24) Big5 點陣字型，字形取自倚天中文系統原生 24 點字。

輸出格式（對齊 fontchinese.cpp 的 loadHiResFont）：
    repeated { big-endian Big5 code (uint16), kHiH*(kHiW/8) glyph bytes }, 0xFFFF 終結

24×24 → 每列 3 bytes × 24 列 = 72 bytes/字，**與倚天 24 點原生 stride 完全相同**，
所以這支工具其實只是「挑出用到的字 + 加上 Big5 碼前綴」，不做任何重新取樣。

[HARD] 尺寸必須與引擎常數一致（kHiW=24 / kHiH=24 / kBig5WidthHi=12）。
kq4 踩過：引擎寫 20×20、建構腳本烘 24×22，兩邊不一致 → 引擎逐字讀錯位，
畫面上中文字互相重疊、破碎。改這裡就要同步改 fontchinese.cpp，反之亦然。

為什麼是 24×24 而不是 TTF 縮的 24×22：
  視覺大小 = 字模寬 ÷ 畫布寬。24×24 在 640 畫布 = 3.75%，與原版 12×12 在 320 畫布同大，
  但細節是 2 倍。而且倚天 24 點是為該尺寸手工調的，TTF 縮放的複雜字會黏連。

用法：bake_hires_eten.py <out.fnt> <tsv1> [tsv2 ...] [--std PATH] [--spc PATH] [--embolden]
純 stdlib。
"""
import sys, os, struct, argparse

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from eten_font import EtenFont

W, H = 24, 24
ROW_BYTES = W // 8
GLYPH_BYTES = ROW_BYTES * H


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("out")
    ap.add_argument("tsv", nargs="+")
    ap.add_argument("--std", default="art/fonts/STDFONT.24",
                    help="倚天 24 點漢字（用 etunpack.py 從 STD.24M 解出）")
    ap.add_argument("--spc", default="art/fonts/SPCFONT.24", help="倚天 24 點全形符號")
    ap.add_argument("--embolden", action="store_true", help="筆劃水平膨脹 1px")
    a = ap.parse_args()

    chars = set()
    for path in a.tsv:
        for line in open(path, encoding="utf-8"):
            if "\t" not in line:
                continue
            en, zh = line.rstrip("\n").split("\t", 1)
            if zh and zh != en:
                chars.update(zh)

    eten = EtenFont(a.std, a.spc, 24)
    glyphs, missing = [], []
    for ch in sorted(chars):
        try:
            b5 = eten.big5(ch)
        except UnicodeEncodeError:
            continue
        if len(b5) != 2:
            continue
        g = eten.glyph(ch)
        if g is None:
            missing.append(ch)
            continue
        if len(g) != GLYPH_BYTES:
            missing.append(ch)
            continue
        if a.embolden:
            g = eten.embolden(g)
        glyphs.append(((b5[0] << 8) | b5[1], g))

    if missing:
        # fallback 數量是品質指標：一大批掉進來時先懷疑索引公式或漏帶 SPCFONT
        sys.stderr.write(f"WARN 倚天 24 點字庫查無 {len(missing)} 字：{''.join(missing)}\n")

    with open(a.out, "wb") as out:
        for code, bmp in glyphs:
            out.write(struct.pack(">H", code))
            out.write(bmp)
        out.write(struct.pack(">H", 0xFFFF))
    print(f"hi-res 字型 {len(glyphs)} 字（倚天 {W}x{H}）→ {a.out}")


if __name__ == "__main__":
    main()
