#!/bin/bash
# 進遊戲擷取：滑鼠點 Start New Game → 跳過開場 → 截狀態列／選單／對白框。
# [雷] xdotool key --window 對 SDL2 無效 → 先 windowactivate 再送 XTEST 事件。
# [雷] 開場選單（See the Intro / Start New Game / Restore Game）Escape 與 Tab 都無效，要滑鼠點。
set -e
export HOME=/tmp XDG_RUNTIME_DIR=/tmp DISPLAY=:99
Xvfb :99 -screen 0 640x480x24 >/tmp/xvfb.log 2>&1 &
sleep 2
cd /src
PREFIX="${PREFIX:-ingame}"
EXTRA="${EXTRA:-}"
timeout 260 ./scummvm --path=/game --auto-detect $EXTRA 2>/tmp/sv.log &
sleep 8
WID=$(xdotool search --class scummvm | head -1)
echo "WID=$WID"
xdotool windowactivate "$WID" 2>/dev/null || true
sleep 1
shot() { import -window root "/out/shots/${PREFIX}_$1.png" 2>/dev/null || true; }
click() { xdotool mousemove "$1" "$2"; sleep 1; xdotool click 1; }

# [雷] 選單出現時機會浮動（credits 輪播中才疊上來）→ 別用固定 sleep，重複點到進去為止。
# 點空無害；已進遊戲時該座標的點擊只是叫亞瑟走一步。
for i in 1 2 3 4 5 6 7 8; do
  click 455 415
  sleep 4
  shot "01_try$i"
done
# 開場動畫：Escape 逐段跳過
for i in 1 2 3 4 5 6 7 8; do
  xdotool key Escape; sleep 3
  shot "03_esc$i"
done
sleep 3
shot "04_gameplay"
# 滑鼠移到畫面頂端叫出選單列（SCI0 選單）
xdotool mousemove 320 3; sleep 2
shot "05_menubar"
xdotool mousemove 320 240; sleep 1
# parser 打 look
xdotool type --delay 120 "look"; sleep 1; xdotool key Return; sleep 4
shot "06_look"
xdotool key Return; sleep 2
shot "07_after"
pkill -f "scummvm --path" 2>/dev/null || true
echo "=== stderr tail ==="; grep -vE "ALSA|snd_" /tmp/sv.log | tail -10
