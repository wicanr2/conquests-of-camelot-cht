#!/bin/bash
# 側錄原版 MT-32 音樂當推廣片配樂（rulebook 93 鐵則 1：配樂用原版真實素材，不自產）。
#
# [HARD] 不要設 SDL_DISKAUDIODELAY=0。
#   SCI 的音樂排序器依「遊戲時鐘」推進；把 disk audio 設成全速輸出，mixer 會以 CPU
#   全速灌出 GB 級檔案，而且因為排序器沒跟著跑，內容整段是靜音。必須即時側錄。
#
# 輸出：/out/cap.raw（44100 Hz / stereo / s16le，ScummVM 的預設 mixer 格式）
set -e
export HOME=/tmp XDG_RUNTIME_DIR=/tmp DISPLAY=:99
Xvfb :99 -screen 0 640x480x24 >/tmp/xvfb.log 2>&1 &
XVFB_PID=$!
sleep 2
cd /src

SECS="${SECS:-150}"
export SDL_AUDIODRIVER=disk
export SDL_DISKAUDIOFILE=/out/cap.raw

# --music-driver=mt32 走 Munt 模擬器；ROM 由 --extrapath 帶入
timeout "$SECS" ./scummvm --path=/game --auto-detect --language=tw \
  --extrapath=/cht --music-driver=mt32 --music-volume=255 \
  >/tmp/sv.log 2>&1 &
SV_PID=$!
sleep 10

WID=$(xdotool search --class scummvm | head -1 || true)
if [ -n "$WID" ]; then
  xdotool windowactivate "$WID" 2>/dev/null || true
fi
sleep 1

# 開場：標題畫面 → 選單 →「開始新遊戲」。前段留著標題曲，之後是城堡場景音樂。
sleep 20
for i in 1 2 3 4; do xdotool mousemove 455 415; sleep 1; xdotool click 1; sleep 4; done

# 讓它自己跑完剩下的時間（即時側錄，不催）
wait $SV_PID 2>/dev/null || true
# [雷] 別用 pkill -f 收——會連這支腳本自己一起殺掉（exit 144）
kill "$XVFB_PID" 2>/dev/null || true

echo "=== scummvm log (尾) ==="
grep -viE "ALSA|snd_" /tmp/sv.log | tail -20
echo "=== cap.raw ==="
ls -la /out/cap.raw
