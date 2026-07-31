#!/usr/bin/env python3
"""譯文顯示寬度檢查：找出會撐破對話框的句子。

為什麼不用字元數比：中文一個字佔兩個顯示格，英文一個字母佔一格。
「長度 ±30%」若按字元數算會誤判——同樣 20 字元，中文的實際寬度是英文的兩倍。
所以要按**顯示寬度**（全形算 2、半形算 1）比。

本作對白框只有約 14 個英文字元寬（＝7 個中文字），SCI0 又會依量到的文字寬度開框，
譯文太長不是溢出，是把框撐得比畫面還大。

用法：scan_width.py <translation_utf8.tsv> [--ratio 1.30] [--min-width 20]
"""
import sys, argparse, unicodedata


def dwidth(s):
    return sum(2 if unicodedata.east_asian_width(c) in "WF" else 1 for c in s)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("tsv")
    ap.add_argument("--ratio", type=float, default=1.30, help="超過原文幾倍寬就報")
    ap.add_argument("--min-width", type=int, default=20,
                    help="原文太短時比例沒有意義，低於此寬度不檢查")
    a = ap.parse_args()

    over, total = [], 0
    for ln, line in enumerate(open(a.tsv, encoding="utf-8"), 1):
        if "\t" not in line:
            continue
        en, zh = line.rstrip("\n").split("\t", 1)
        if not zh or zh == en:
            continue
        total += 1
        we, wz = dwidth(en), dwidth(zh)
        if we >= a.min_width and wz > we * a.ratio:
            over.append((wz / we, ln, we, wz, en, zh))

    over.sort(reverse=True)
    print(f"已譯 {total} 則，顯示寬度超過原文 {a.ratio:.0%} 的有 {len(over)} 則")
    for r, ln, we, wz, en, zh in over[:20]:
        print(f"\n  行{ln}  {r:.2f}x（英 {we} → 中 {wz}）")
        print(f"    {en[:80]}")
        print(f"    {zh[:50]}")
    return 1 if over else 0


if __name__ == "__main__":
    sys.exit(main())
