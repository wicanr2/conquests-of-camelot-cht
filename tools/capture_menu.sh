#!/bin/bash
# 進遊戲後叫出選單列並逐個點開，驗證中文選單。
# 驗的是 LSL2 踩過的坑：SCI0 選單列只有 9px 高，中文 14px 會溢出清不掉 → 殘影。
set -e
export HOME=/tmp XDG_RUNTIME_DIR=/tmp DISPLAY=:99
Xvfb :99 -screen 0 640x480x24 >/tmp/xvfb.log 2>&1 &
sleep 2
cd /src
PREFIX="${PREFIX:-menu}"
EXTRA="${EXTRA:-}"
timeout 280 ./scummvm --path=/game --auto-detect $EXTRA 2>/tmp/sv.log &
sleep 8
WID=$(xdotool search --class scummvm | head -1)
xdotool windowactivate "$WID" 2>/dev/null || true
sleep 1
shot() { import -window root "/out/shots/${PREFIX}_$1.png" 2>/dev/null || true; }
click() { xdotool mousemove "$1" "$2"; sleep 1; xdotool click 1; }

# 進遊戲（選單出現時機浮動，重複點）
for i in 1 2 3 4 5 6 7 8; do click 455 415; sleep 4; done
# 跳過開場
for i in 1 2 3 4 5 6; do xdotool key Escape; sleep 3; done
# 推進到可操作狀態
xdotool type --delay 120 "look"; sleep 1; xdotool key Return; sleep 4
xdotool key Return; sleep 2
shot "00_ingame"

# 選單列：滑鼠移到畫面最上緣
xdotool mousemove 320 2; sleep 2
shot "01_bar"
# 逐個點開五個選單（座標依 640 寬畫面估，中文寬度不同故多點幾處）
x=40
for i in 1 2 3 4 5; do
  xdotool mousemove $x 2; sleep 1
  xdotool click 1; sleep 2
  shot "02_menu_x$x"
  xdotool key Escape; sleep 1
  x=$((x + 90))
done
# 離開選單後回到畫面，檢查有無殘影
xdotool mousemove 320 240; sleep 2
shot "03_after_menu"
pkill -f "scummvm --path" 2>/dev/null || true
echo "=== stderr tail ==="; grep -vE "ALSA|snd_" /tmp/sv.log | tail -8
