#!/bin/bash
# 探測 ScummVM debugger 是否可用、遊戲物件叫什麼名字（供 send ?<obj> newRoom 換場用）。
# [雷] 開 console 之前先把畫面上的訊息框點掉——框開著的時候遊戲主迴圈是停的。
set -e
export HOME=/tmp XDG_RUNTIME_DIR=/tmp DISPLAY=:99
Xvfb :99 -screen 0 640x480x24 >/tmp/xvfb.log 2>&1 &
sleep 2
cd /src
timeout 200 ./scummvm --path=/game --auto-detect --language=tw 2>/tmp/sv.log &
sleep 8
WID=$(xdotool search --class scummvm | head -1)
xdotool windowactivate "$WID" 2>/dev/null || true
sleep 1
shot() { import -window root "/out/shots/probe_$1.png" 2>/dev/null || true; }

# 進遊戲
for i in 1 2 3 4 5 6; do xdotool mousemove 455 415; sleep 1; xdotool click 1; sleep 4; done
for i in 1 2 3; do xdotool key Escape; sleep 3; done
# 把可能開著的訊息框點掉
xdotool key Return; sleep 2
xdotool key Return; sleep 2
shot "00_before_console"

# 開 debugger console
xdotool key ctrl+alt+d; sleep 3
shot "01_console"
# 查遊戲物件：g1 是 game object（g0=ego, g2=room）
xdotool type --delay 100 "vmvars g 1"; sleep 1; xdotool key Return; sleep 2
shot "02_vmvars"
xdotool type --delay 100 "vmvars g 0"; sleep 1; xdotool key Return; sleep 2
shot "03_vmvars0"
echo "=== stderr ==="; grep -vE "ALSA|snd_" /tmp/sv.log | tail -8
pkill -f "scummvm --path" 2>/dev/null || true
