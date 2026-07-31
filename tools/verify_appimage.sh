#!/bin/bash
# 實際跑一次 AppImage 並截圖——「檔案產出來了」不等於「玩得動」。
# APP 由環境變數帶入（容器內路徑），PREFIX 決定截圖檔名。
set -e
export HOME=/tmp XDG_RUNTIME_DIR=/tmp DISPLAY=:99
Xvfb :99 -screen 0 640x480x24 >/tmp/xvfb.log 2>&1 &
sleep 2
cd /out
APP="${APP:-/app/CAMELOT-CHT-full-x86_64.AppImage}"
PREFIX="${PREFIX:-appimage}"
timeout 80 "$APP" --appimage-extract-and-run 2>/tmp/app.log &
sleep 14
import -window root /out/shots/${PREFIX}_boot.png 2>/dev/null || true
# 進遊戲（開場選單只吃滑鼠、出現時機浮動 → 重複點）
for i in 1 2 3 4 5; do xdotool mousemove 455 415; sleep 1; xdotool click 1; sleep 4; done
for i in 1 2 3; do xdotool key Escape; sleep 3; done
xdotool key Return; sleep 2
xdotool type --delay 120 "look"; sleep 1; xdotool key Return; sleep 4
import -window root /out/shots/${PREFIX}_ingame.png 2>/dev/null || true
pkill -f scummvm 2>/dev/null || true
echo "=== MT-32 / 中文資料載入狀況 ==="
grep -iE "MT32|falling back|cannot be used|translation" /tmp/app.log | head -5
echo "=== 錯誤 ==="
grep -iE "error|failed|not found" /tmp/app.log | grep -viE "alsa|snd_" | head -5
