#!/bin/bash
# 推廣片素材擷取。
#
# [雷] 既有的 capture_ingame.sh 預設不帶 --language=tw／--extrapath（那是英文對照組用的），
#      這支一律帶齊，避免又拍出一批英文素材。
# [雷] 開場選單的座標是 (455,132) 觀看片頭 / (455,182) 開始新遊戲 / (455,228) 讀取遊戲。
#      capture_ingame.sh 裡的 (455,415) 是更早期版本的座標，現在點空。
set -e
export HOME=/tmp XDG_RUNTIME_DIR=/tmp DISPLAY=:99
Xvfb :99 -screen 0 640x480x24 >/tmp/xvfb.log 2>&1 &
XVFB_PID=$!
sleep 2
cd /src
PREFIX="${PREFIX:-promo}"
MODE="${MODE:-intro}"       # intro = 錄片頭；game = 錄遊戲畫面
timeout 280 ./scummvm --path=/game --auto-detect --language=tw --extrapath=/cht 2>/tmp/sv.log &
SV_PID=$!
sleep 8
WID=$(xdotool search --class scummvm | head -1)
xdotool windowactivate "$WID" 2>/dev/null || true
sleep 1
shot() { import -window root "/out/shots/${PREFIX}_$1.png" 2>/dev/null || true; }
click() { xdotool mousemove "$1" "$2"; sleep 1; xdotool click 1; }

# credits 輪播結束後選單才疊上來 → 重複點到進去為止
if [ "$MODE" = intro ]; then
  for i in 1 2 3 4 5 6; do click 455 132; sleep 3; done
  shot "00_menu"
  # 片頭完整播放，每 3 秒一張
  for i in $(seq -w 1 40); do sleep 3; shot "in_$i"; done
else
  for i in 1 2 3 4 5 6; do click 455 182; sleep 3; done
  sleep 5
  shot "10_gameplay"
  xdotool key Return; sleep 2
  # 選單列（SCI0 把選單掛在畫面頂端）
  xdotool mousemove 320 3; sleep 2; shot "11_menubar"
  xdotool mousemove 320 240; sleep 1; xdotool key Escape; sleep 1
  # parser 打 look 觸發房間敘述
  xdotool type --delay 120 "look"; sleep 1; xdotool key Return; sleep 4
  shot "12_look"
  xdotool key Return; sleep 2
  # 道具欄
  xdotool type --delay 120 "inventory"; sleep 1; xdotool key Return; sleep 4
  shot "13_inventory"
  xdotool key Return; sleep 2
  # 與人物對話
  xdotool type --delay 120 "ask about grail"; sleep 1; xdotool key Return; sleep 4
  shot "14_ask"
  xdotool key Return; sleep 2
  shot "15_after"
fi

kill "$SV_PID" 2>/dev/null || true
kill "$XVFB_PID" 2>/dev/null || true
echo "=== stderr tail ==="; grep -viE "ALSA|snd_" /tmp/sv.log | tail -6
ls /out/shots/${PREFIX}_* | wc -l
