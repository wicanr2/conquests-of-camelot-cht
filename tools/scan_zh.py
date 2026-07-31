#!/usr/bin/env python3
"""譯文用字檢查：簡體字、兩岸共用碼誤用、中國大陸用語。

分工（三道都要跑，都不充分）：
  validate_batch.py  機械檢查（行數、key、控制序列、Big5 可編）
  scan_zh.py         用字檢查（本檔）
  人工抽樣 + 實機    語意層（因果講反、指涉不明、謎語在中文無解）

## 為什麼不用單字清單掃簡體

Big5 是繁體字集，「國說這時會來對」的簡體形根本編不進 Big5，
`validate_batch.py` 的 Big5 檢查已經全部擋掉了。真正漏網的只有兩類：

1. **Big5 也收的簡化字**（个／么／万／与…）——字數少，逐字列得完。
2. **兩岸共用碼用錯邊**（后／裡／麵／製…）——單看字元無法判斷對錯，
   「皇后」對、「以后」錯，**必須用詞組比對**。

早期版本用一長串單字當簡體表，把「只」「台」這種繁體正字也列進去，
結果整批都是誤報。**寧可漏報也不要淹沒真問題。**
"""
import sys, re

# 一、Big5 也收得進去的簡化字（逐字列，確定是簡體專用才列）
SIMPLIFIED_IN_BIG5 = {
    "个": "個", "么": "麼", "万": "萬", "与": "與",
}
# 註：早期版本還列了 占／丑／凶／別／為 等，全是誤報來源——
# 「占卜」「丑角」「吉凶」都是繁體正字，錯的只是特定詞（占領→佔領、丑陋→醜陋），
# 那些交給下面的詞組規則。其餘簡體字不在 Big5，validate_batch.py 已擋掉。

# 二、共用碼誤用（詞組比對，準度遠高於單字）
WRONG_PHRASES = [
    (r"以后|之后|然后|最后|后面|后來|后来|背后|隨后|随后|事后|以后", "后 → 後（「后」只用於皇后／王后）"),
    (r"那里|哪里|里面|里頭|里头|心里|手里|夜里|家里", "里 → 裡（「里」只用於長度或村里）"),
    (r"干净|干燥|干旱|干杯|干脆|干預|干扰", "干 → 乾／幹（視語意）"),
    (r"面包|面條|面条|泡面|拉面", "面 → 麵（食物）"),
    (r"制作|制造|制成|自制", "制 → 製（製作／製造）"),
    (r"发現|发现|头发|理发", "发 → 發／髮"),
    (r"松開|松开|放松|轻松|輕松", "松 → 鬆"),
    (r"准備|准备|标准的", "准 → 準"),
    # 量詞「只」不一律報：台灣用法「一只杯子／一只戒指」（器物）是對的，
    # 「一隻鳥／一隻狗」（動物）才用隻。只報明確搭配動物的情形。
    (r"一只(鳥|狗|貓|馬|羊|牛|豬|雞|鴨|鵝|兔|鼠|虎|狼|熊|魚|鹿|驢|駱駝|野豬|烏鴉)", "只 → 隻（動物用隻）"),
    (r"手表|表面上看|钟表", "表 → 錶（計時器）"),
    (r"象征", "象征 → 象徵"),
    (r"占領|占据|占據|占有欲", "占 → 佔（動詞用佔，占卜／占星用占）"),
    (r"丑陋|丑聞|丑闻", "丑 → 醜"),
    (r"回避|迴避", None),  # 兩者皆可，不報
]

# 三、中國大陸用語
MAINLAND = {
    "視頻": "影片", "质量": "品質", "信息": "訊息", "軟件": "軟體",
    "網絡": "網路", "屏幕": "螢幕", "默認": "預設", "鼠標": "滑鼠",
    "內存": "記憶體", "硬盤": "硬碟", "菜單": "選單", "激活": "啟用",
    "登錄": "登入", "缺省": "預設", "打印": "列印", "存儲": "儲存",
    "土豆": "馬鈴薯", "沒問題吧": None,
}
# 誤報清單：這些是正常繁中，別報
FALSE_POSITIVE = ("程序", "一會兒", "水平線", "水平面", "皇后", "王后", "太后")


def scan(path):
    problems = []
    for ln_no, ln in enumerate(open(path, encoding="utf-8"), 1):
        if "\t" not in ln:
            continue
        _en, zh = ln.rstrip("\n").split("\t", 1)

        for ch in zh:
            if ch in SIMPLIFIED_IN_BIG5:
                problems.append((ln_no, "簡體", f"{ch} → {SIMPLIFIED_IN_BIG5[ch]}", zh[:60]))
            elif ord(ch) > 127:
                try:
                    ch.encode("big5")
                except UnicodeEncodeError:
                    problems.append((ln_no, "非Big5", f"{ch!r} — 整則譯文會被丟棄", zh[:60]))

        for pat, hint in WRONG_PHRASES:
            if hint and re.search(pat, zh):
                problems.append((ln_no, "共用碼", hint, zh[:60]))

        for bad, good in MAINLAND.items():
            if good and bad in zh:
                problems.append((ln_no, "陸用語", f"{bad} → {good}", zh[:60]))
    return problems


def main():
    total = 0
    for path in sys.argv[1:]:
        ps = scan(path)
        total += len(ps)
        if ps:
            print(f"=== {path} — {len(ps)} 處 ===")
            for ln_no, kind, detail, ctx in ps:
                print(f"  行{ln_no:4d} [{kind}] {detail}\n        {ctx}")
        else:
            print(f"✓ {path}")
    if total:
        print(f"\n合計 {total} 處待處理")
        sys.exit(1)
    print("用字檢查通過（無簡體、無陸用語、全 Big5）")


if __name__ == "__main__":
    main()
