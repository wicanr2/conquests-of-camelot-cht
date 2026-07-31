#!/usr/bin/env python3
"""把 1991 年雜誌廣告的左右兩頁掃描接成一張完整跨頁。

兩頁是分開掃的，會有兩個問題：① 內側（裝訂邊）常留一條黑邊或白邊；
② 兩頁不會掃在同一個高度，直接並排的話上方那條橫幅字和 logo 會錯開。

所以做法是：先把內側邊緣的雜邊裁掉，再**沿接縫自動找垂直位移**——
拿左頁最右邊那幾欄跟右頁最左邊那幾欄比對，取差異最小的位移量。
判準看得見：接完之後上方 SPACE / QUEST I 那條藍底橫幅應該連成一直線。

用法: merge_banner.py <左頁> <右頁> <輸出> [--width N]
"""
import sys
from PIL import Image


def trim_edge(im, side, max_trim=40):
    """裁掉內側的掃描雜邊（整欄接近純黑或純白就當雜邊）。"""
    px = im.load()
    w, h = im.size
    rng = range(w - 1, w - 1 - max_trim, -1) if side == "right" else range(max_trim)
    cut = 0
    for x in rng:
        vals = [sum(px[x, y]) / 3 for y in range(0, h, 7)]
        avg = sum(vals) / len(vals)
        spread = max(vals) - min(vals)
        if avg < 42 or (avg > 232 and spread < 40):
            cut += 1
        else:
            break
    if not cut:
        return im
    return im.crop((0, 0, w - cut, h)) if side == "right" else im.crop((cut, 0, w, h))


def seam_cost(a, b, dy, cols=14):
    """左頁最右 cols 欄 vs 右頁最左 cols 欄，在垂直位移 dy 下的平均色差。"""
    pa, pb = a.load(), b.load()
    wa, ha = a.size
    wb, hb = b.size
    tot = n = 0
    for y in range(0, min(ha, hb), 5):
        ya, yb = y, y + dy
        if not (0 <= ya < ha and 0 <= yb < hb):
            continue
        for k in range(cols):
            ca = pa[wa - 1 - k, ya]
            cb = pb[k, yb]
            tot += abs(ca[0] - cb[0]) + abs(ca[1] - cb[1]) + abs(ca[2] - cb[2])
            n += 1
    return tot / max(n, 1)


def main():
    left, right, out = sys.argv[1], sys.argv[2], sys.argv[3]
    width = None
    if "--width" in sys.argv:
        width = int(sys.argv[sys.argv.index("--width") + 1])

    a = trim_edge(Image.open(left).convert("RGB"), "right")
    b = trim_edge(Image.open(right).convert("RGB"), "left")
    print(f"  裁邊後 左 {a.size}  右 {b.size}")

    best = min(range(-40, 41), key=lambda dy: seam_cost(a, b, dy))
    print(f"  接縫最佳垂直位移 dy={best}px（右頁相對左頁往{'下' if best < 0 else '上'}移）")

    top = max(0, best)
    hh = min(a.size[1] - max(0, -best), b.size[1] - max(0, best))
    ac = a.crop((0, max(0, -best), a.size[0], max(0, -best) + hh))
    bc = b.crop((0, max(0, best), b.size[0], max(0, best) + hh))
    del top

    canvas = Image.new("RGB", (ac.size[0] + bc.size[0], hh))
    canvas.paste(ac, (0, 0))
    canvas.paste(bc, (ac.size[0], 0))

    if width and canvas.size[0] > width:
        h = round(canvas.size[1] * width / canvas.size[0])
        canvas = canvas.resize((width, h), Image.LANCZOS)
    canvas.save(out, quality=88, optimize=True)
    print(f"→ {out}  {canvas.size}")


if __name__ == "__main__":
    main()
