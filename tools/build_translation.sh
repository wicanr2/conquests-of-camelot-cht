#!/bin/bash
# 合併所有譯文 batch → 烘 16px + hi-res 字型 + runtime tsv。可重跑。
set -e
cd "$(dirname "$0")/.."
SKEL=translation/full_skeleton.tsv
OUT_UTF8=translation/translation_utf8.tsv
# 收集所有譯文來源：預填 + 已完成批（.done 檔在 translation/done/ 不是 batch/，別漏——
# 漏了會只剩 skeleton 英文、把 master 洗成 0% 覆蓋，踩過）
BATCHES=$(ls translation/batch/*.tsv translation/done/*.done 2>/dev/null || true)
python3 tools/merge_translations.py "$SKEL" "$OUT_UTF8" $BATCHES
# 對全部譯文(含預填)套全域收斂
python3 - "$OUT_UTF8" <<PYEOF
import sys
conv=[]
for l in open('translation/converge.tsv',encoding='utf-8'):
    if l.startswith('#') or '\t' not in l: continue
    a,b=l.rstrip('\n').split('\t',1); conv.append((a,b))
p=sys.argv[1]; lines=open(p,encoding='utf-8').read().split('\n')
out=[]
for ln in lines:
    if '\t' in ln:
        en,zh=ln.split('\t',1)
        for a,b in conv: zh=zh.replace(a,b)
        out.append(en+'\t'+zh)
    else: out.append(ln)
open(p,'w',encoding='utf-8').write('\n'.join(out))
PYEOF
# 統計覆蓋
python3 - <<PY
import re
n=t=0
for l in open("$OUT_UTF8",encoding='utf-8'):
    if '\t' not in l: continue
    en,zh=l.rstrip('\n').split('\t',1); t+=1
    if zh.strip()!=en.strip(): n+=1
print(f"覆蓋: {n}/{t} ({100*n//t}%) 已譯")
PY
# 烘 16x15 低解析（倚天原生點陣）+ runtime Big5 tsv → dist-cht/（版控快照，打包與 CI 都從這裡取）
mkdir -p dist-cht
python3 tools/build_cht.py "$OUT_UTF8" dist-cht --size 15
# 烘 hi-res（倚天原生 24 點）：尺寸須對齊 fontchinese.cpp 的 kHiW=24 / kHiH=24 / kBig5WidthHi=12
# [雷] 兩邊不一致 → 引擎逐字讀錯位，畫面上中文字互相重疊（kq4 遺留的 20x20 vs 24x22 就是這個坑）
python3 tools/bake_hires_eten.py dist-cht/camelot_big5_hi.fnt "$OUT_UTF8"
# 部署到遊戲目錄（引擎讀寫死檔名，走 SearchMan）
cp dist-cht/translation.tsv dist-cht/camelot_big5.fnt dist-cht/camelot_big5_hi.fnt game/
# 標題疊圖（缺檔時引擎會靜默略過，不影響其他中文化）
[ -f dist-cht/camelot_title.ovl ] && cp dist-cht/camelot_title.ovl game/
echo "=== 產物 ==="
ls -la dist-cht/
