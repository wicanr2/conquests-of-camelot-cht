#!/bin/bash
# 用 debugger 換場，逐一跳進場景截圖。
# [HARD] 換場要用 send ?ARTHUR newRoom <n>，不能用 console 的 room <n>
#        （後者只改全域變數，房間腳本下一輪又蓋回去 → 印了訊息畫面卻沒動）。
# 遊戲物件名 ARTHUR 由 `vmvars g 1` 實測得到。
# ROOMS 由環境變數帶入（空白分隔）。
set -e
export HOME=/tmp XDG_RUNTIME_DIR=/tmp DISPLAY=:99
Xvfb :99 -screen 0 640x480x24 >/tmp/xvfb.log 2>&1 &
sleep 2
cd /src
PREFIX="${PREFIX:-room}"
ROOMS="${ROOMS:-10 20 30}"
timeout 280 ./scummvm --path=/game --auto-detect --language=tw 2>/tmp/sv.log &
sleep 8
WID=$(xdotool search --class scummvm | head -1)
xdotool windowactivate "$WID" 2>/dev/null || true
sleep 1
shot() { import -window root "/out/shots/${PREFIX}_$1.png" 2>/dev/null || true; }

# 進遊戲（選單出現時機浮動 → 重複點）
for i in 1 2 3 4 5 6; do xdotool mousemove 455 415; sleep 1; xdotool click 1; sleep 4; done
for i in 1 2 3; do xdotool key Escape; sleep 3; done
xdotool key Return; sleep 2

for r in $ROOMS; do
  xdotool key ctrl+alt+d; sleep 2
  xdotool type --delay 80 "send ?ARTHUR newRoom $r"; sleep 1
  xdotool key Return; sleep 1
  # [雷] 再按一次 ctrl+alt+d 不會關掉 console（截圖會被 console 蓋滿）——要打 exit。
  xdotool type --delay 80 "exit"; sleep 1
  xdotool key Return; sleep 4
  xdotool key Return; sleep 2          # 把可能跳出的訊息框推掉
  shot "r${r}_a"
  # parser 打 look 觸發房間描述（比等自動旁白穩）
  xdotool type --delay 100 "look"; sleep 1; xdotool key Return; sleep 3
  shot "r${r}_b"
  xdotool key Return; sleep 1
done
echo "=== stderr ==="; grep -vE "ALSA|snd_" /tmp/sv.log | tail -10
pkill -f "scummvm --path" 2>/dev/null || true
