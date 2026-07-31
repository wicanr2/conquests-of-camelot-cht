#!/usr/bin/env python3
"""倚天中文系統 (ETEN 3.53) 原生點陣字讀取器。

為什麼不用 TTF rasterize：1990s DOS 中文遊戲的中文長什麼樣，倚天就長什麼樣。
TTF 縮到 15px 會糊、筆劃比例不對；倚天是為該尺寸手工調的點陣。

檔案（從 ET353S.iso 取出，放 art/fonts/）：
  STDFONT.15  16×15 漢字 13094 字，stride 30
  SPCFONT.15  16×15 全形符號 408 字，stride 30  ← [雷] 漏帶會讓 ，。！？「」 全部掉 fallback

點陣佈局：每列 (W+7)/8 bytes，MSB-first，由上而下。

[HARD] Big5 分區索引不是線性的。動任何東西前先跑 `python3 tools/eten_font.py --verify`：
idx=0 必須是「一」（一條橫線），「中」「猴」要能辨識。這關沒過就整批字會整體偏移，
症狀是「有字但全都不對」。
"""
import sys

W, H, STRIDE = 16, 15, 30


def _raw(hi, lo):
    """Big5 高低位元組 → 線性序號。"""
    return (hi - 0xA1) * 157 + ((lo - 0x40) if lo < 0x7F else (lo - 0x62))


LAST_SPC = _raw(0xA3, 0xBF)      # 符號區尾 = 407
BASE_A440 = _raw(0xA4, 0x40)     # 漢字區起點
LAST_COMMON = _raw(0xC6, 0x7E)   # 常用字尾
BASE_C940 = _raw(0xC9, 0x40)     # 次常用起點
N_COMMON = 5401

# Python big5 codec 與 Big5 表對不上的全形符號（U+FF5E vs U+301C 之類的歧義）
MANUAL_BIG5 = {"～": b"\xa1\xe3"}


class EtenFont:
    def __init__(self, std_path, spc_path):
        self.std = open(std_path, "rb").read()
        self.spc = open(spc_path, "rb").read()
        if len(self.std) // STRIDE != 13094:
            sys.stderr.write(f"WARN STDFONT 字數 {len(self.std)//STRIDE} ≠ 13094，檔案可能不對\n")
        if len(self.spc) // STRIDE != 408:
            sys.stderr.write(f"WARN SPCFONT 字數 {len(self.spc)//STRIDE} ≠ 408，檔案可能不對\n")

    def big5(self, ch):
        if ch in MANUAL_BIG5:
            return MANUAL_BIG5[ch]
        return ch.encode("big5")

    def glyph(self, ch):
        """回傳該字的 30 bytes 點陣；查無回 None。"""
        try:
            b = self.big5(ch)
        except UnicodeEncodeError:
            return None
        if len(b) != 2:
            return None
        r = _raw(b[0], b[1])
        if r <= LAST_SPC:
            data, idx = self.spc, r
        elif r <= LAST_COMMON:
            data, idx = self.std, r - BASE_A440
        else:
            data, idx = self.std, N_COMMON + (r - BASE_C940)
        if idx < 0 or (idx + 1) * STRIDE > len(data):
            return None
        return data[idx * STRIDE:(idx + 1) * STRIDE]

    def ascii_art(self, ch):
        g = self.glyph(ch)
        if g is None:
            return [f"(無 {ch})"]
        return [
            "".join("#" if g[y * 2 + xb] & (0x80 >> b) else "." for xb in range(2) for b in range(8))
            for y in range(H)
        ]

    def embolden(self, g):
        """筆劃水平膨脹 1px（每列與左移一格 OR）。15 點倚天只有偏細的明體，
        想要粗一點時用這個，比把 24 點黑體縮到 15 點好（縮放會讓複雜字黏連）。"""
        out = bytearray(g)
        for y in range(H):
            hi, lo = g[y * 2], g[y * 2 + 1]
            v = (hi << 8) | lo
            v |= (v << 1) & 0xFFFF
            out[y * 2] = (v >> 8) & 0xFF
            out[y * 2 + 1] = v & 0xFF
        return bytes(out)


def _verify(std="art/fonts/STDFONT.15", spc="art/fonts/SPCFONT.15"):
    f = EtenFont(std, spc)
    print(f"STDFONT {len(f.std)//STRIDE} 字、SPCFONT {len(f.spc)//STRIDE} 字\n")
    ok = True
    # idx=0 必須是「一」：只有一條橫線，且該列幾乎全亮
    g = f.std[:STRIDE]
    rows = ["".join("#" if g[y * 2 + xb] & (0x80 >> b) else "." for xb in range(2) for b in range(8))
            for y in range(H)]
    inked = [r for r in rows if "#" in r]
    if len(inked) > 2 or not any(r.count("#") >= 12 for r in inked):
        ok = False
        print("✗ STDFONT idx=0 不像「一」")
    for r in rows:
        print(r)
    for ch in "中猴，。「」":
        print(f"\n=== {ch} ===")
        for r in f.ascii_art(ch):
            print(r)
        if f.glyph(ch) is None or not any("#" in r for r in f.ascii_art(ch)):
            ok = False
            print(f"✗ {ch} 取不到點陣")
    print("\n" + ("✓ oracle 通過" if ok else "✗ oracle 失敗——索引公式或字型檔有問題，先修這個"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(_verify())
