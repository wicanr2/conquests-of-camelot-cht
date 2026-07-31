#!/usr/bin/env python3
"""譯名漂移掃描：原文出現某個專名時，譯文有沒有用 names.tsv 定案的譯法。

為什麼需要這支：即使每個翻譯批次都拿到同一份 names.tsv，獨立作業仍會漂移
（SQ1 實測：同一個姓氏出現過三種寫法）。批次內部看不出來，合併後才顯形。

與另外兩支的分工：
  validate_batch.py  機械（行數、key、控制序列、Big5 可編）
  scan_zh.py         用字（簡體、共用碼、陸用語）
  scan_consistency.py 譯名漂移（本檔）
三支都測不到語意層的錯（因果講反、指涉不明、謎語在中文無解）——那只能靠人工與實機。

用法：scan_consistency.py <translation_utf8.tsv> [--names translation/names.tsv]
"""
import sys, re, argparse, collections

# 這些 names.tsv 條目不適合當「原文出現就該有對應中文」的規則：
# 保留原文的、當通用詞用的、或本來就常以其他形式出現的。
SKIP = {
    "Widdershins", "Al-Sirat", "Cernunnos", "Liber ex Doctrina", "Al-Uzza",
    "habib", "wadi", "mukhtar", "relic", "henge", "dolmen", "trilithon",
    "m'lord", "sire", "my liege", "dinar", "dirham", "fals", "Goddess",
    "Arthur", "Rome", "Gaza",   # 常以其他組合出現（King Arthur / Roman / Gazan…）
    "Conal Cearnach", "Frastrada", "Athene",  # 船名保留原文；Athene 另有女神義，兩種語境
    "Saracen",        # 單數指 boss、複數泛指海盜，兩義並存
    "Camelot",        # 遊戲標題「Conquests of Camelot」譯「亞瑟王傳奇」，非地名
}


def load_names(path):
    pairs = []
    for line in open(path, encoding="utf-8"):
        line = line.rstrip("\n")
        if not line or line.startswith("#") or "\t" not in line:
            continue
        parts = line.split("\t")
        en, zh = parts[0], parts[1]
        if not en or not zh or en in SKIP or zh.startswith("<"):
            continue
        if en == zh:      # 保留原文的條目
            continue
        pairs.append((en, zh))
    # 長的英文詞先比對，避免 "Camelot" 先命中吃掉 "Conquests of Camelot"
    pairs.sort(key=lambda p: -len(p[0]))
    return pairs


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("tsv")
    ap.add_argument("--names", default="translation/names.tsv")
    ap.add_argument("--max-per-name", type=int, default=3, help="每個專名最多列幾個例子")
    a = ap.parse_args()

    names = load_names(a.names)
    misses = collections.defaultdict(list)
    total_hits = collections.Counter()

    for ln_no, line in enumerate(open(a.tsv, encoding="utf-8"), 1):
        if "\t" not in line:
            continue
        en, zh = line.rstrip("\n").split("\t", 1)
        if not zh or zh == en:
            continue  # 未翻譯
        for name_en, name_zh in names:
            # 英文專名用單字邊界比對，避免 Ali 命中 Alive
            if re.search(r"(?<![A-Za-z])" + re.escape(name_en) + r"(?![A-Za-z])", en):
                total_hits[name_en] += 1
                if name_zh not in zh:
                    misses[name_en].append((ln_no, en[:70], zh[:70]))

    if not misses:
        print(f"✓ 譯名一致（比對 {len(names)} 個專名）")
        return 0

    print(f"譯名漂移：{len(misses)} 個專名有未照表的譯文\n")
    for name_en in sorted(misses, key=lambda k: -len(misses[k])):
        zh = dict(names)[name_en]
        n = len(misses[name_en])
        print(f"■ {name_en} → 應為「{zh}」：{n}/{total_hits[name_en]} 則未命中")
        for ln_no, en, zht in misses[name_en][:a.max_per_name]:
            print(f"    行{ln_no}: {en}")
            print(f"        {zht}")
    print("\n注意：未命中不一定是錯——中文可能用代名詞帶過，或該句在講別的東西。逐條看過再改。")
    return 1


if __name__ == "__main__":
    sys.exit(main())
