#!/usr/bin/env bash
# 《亞瑟王傳奇》繁中化推廣片合成。全 docker、無剪輯軟體、可重跑。
#
# 素材來源鐵則（rulebook 93）：
#   - 配樂 = 原版 MT-32 側錄（tools/record_mt32.sh，即時側錄非全速）
#   - 畫面 = 引擎實機截圖，不調色、不重繪
#
# [雷] 不要用 zoompan：`-loop 1 -t S` + `fps` + `zoompan:d=FPS*S` 會變成 (FPS*S)^2 幀，
#      6 秒能算出兩萬多幀、燒滿 CPU 好幾分鐘。靜態圖 + fade 對 promo 完全夠用。
# [雷] 配樂比影片短時不要用 -shortest：它會以較短的音軌為準，把結尾卡整張截掉。
#      先 aloop 無限循環再 atrim 到影片長度。
set -eu

# ===== theme：羊皮紙與封蠟（色票取自本作實機截圖的 histogram，見 CONTEXT）=====
THEME_NAME='羊皮紙與封蠟'
BG_DEEP='#150c06'      # 近黑的深棕
BG_LITE='#3a2416'      # 陳舊皮革
ACCENT='#c08a2e'       # 金（取自城堡石牆的米金 #9D9A61 提亮）
SEAL='#8c2f22'         # 封蠟紅（王座廳紅地毯 #B2493C 壓暗）
PARCH='#f0e2c0'        # 羊皮（墓窖牆 #FDF1CC 壓一點）
DIM='#a08a68'
FB=/usr/share/fonts/opentype/noto/NotoSerifCJK-Bold.ttc
FR=/usr/share/fonts/opentype/noto/NotoSerifCJK-Regular.ttc
W=1280; H=720; FPS=25
SHOT=/shots; EN=/enshots; ART=/art; OUT=/out; TMP=/tmp/c
mkdir -p "$TMP" "$OUT"

# 母題：遊戲每個畫面四角都有紋章方塊，這裡用同樣的構圖當邊框
bg() { # $1 out
  convert -size ${W}x${H} "radial-gradient:${BG_LITE}-${BG_DEEP}" \
    -fill none -stroke "$ACCENT" -strokewidth 2 -draw "rectangle 24,24 $((W-24)),$((H-24))" \
    -stroke "$SEAL" -strokewidth 1 -draw "rectangle 32,32 $((W-32)),$((H-32))" \
    -stroke none -fill "$SEAL" \
    -draw "rectangle 18,18 54,54"        -draw "rectangle $((W-54)),18 $((W-18)),54" \
    -draw "rectangle 18,$((H-54)) 54,$((H-18))" -draw "rectangle $((W-54)),$((H-54)) $((W-18)),$((H-18))" \
    -fill "$ACCENT" \
    -draw "rectangle 26,26 46,46"        -draw "rectangle $((W-46)),26 $((W-26)),46" \
    -draw "rectangle 26,$((H-46)) 46,$((H-26))" -draw "rectangle $((W-46)),$((H-46)) $((W-26)),$((H-26))" \
    "$1"
}

card() { # $1 out  $2 中標  $3 英標  $4 副標
  bg "$TMP/_bg.png"
  convert "$TMP/_bg.png" -gravity center \
    -font "$FB" -fill '#3a2410' -pointsize 96 -annotate +5-115 "$2" \
    -fill "$ACCENT" -pointsize 96 -annotate +0-120 "$2" \
    -font "$FR" -fill "$PARCH" -pointsize 38 -annotate +0+20 "$3" \
    -font "$FR" -fill "$DIM" -pointsize 29 -annotate +0+130 "$4" "$1"
}

slide_frame() { # $1 out  $2 shot  $3 字幕
  bg "$TMP/_bg.png"
  convert "$SHOT/$2" -filter point -resize x556 -bordercolor "$ACCENT" -border 3 "$TMP/_sc.png"
  convert "$TMP/_bg.png" "$TMP/_sc.png" -gravity north -geometry +0+52 -composite \
    -font "$FR" -fill "$PARCH" -gravity south -pointsize 36 -annotate +0+52 "$3" "$1"
}

slide_full() { # $1 out  $2 shot  $3 字幕
  convert "$SHOT/$2" -filter point -resize ${W}x${H}^ -gravity center -extent ${W}x${H} \
    -fill "#00000099" -draw "rectangle 0,$((H-150)) ${W},${H}" \
    -font "$FR" -fill "$PARCH" -gravity south -pointsize 38 -annotate +0+48 "$3" \
    -fill none -stroke "$ACCENT" -strokewidth 3 -draw "rectangle 12,12 $((W-12)),$((H-12))" "$1"
}

dcard() { # $1 out  $2 引文  $3 出處  —— 大引號、左對齊，和置中標題卡明顯不同
  bg "$TMP/_bg.png"
  convert "$TMP/_bg.png" \
    -font "$FB" -fill "#5a3a18" -pointsize 210 -gravity northwest -annotate +58+10 '“' \
    -font "$FR" -fill "$PARCH" -pointsize 44 -gravity west -annotate +115-20 "$2" \
    -font "$FR" -fill "$DIM" -pointsize 27 -gravity southeast -annotate +110+92 "$3" "$1"
}

split_ba() { # $1 out  $2 左圖  $3 右圖  $4 左標  $5 右標  $6 底標
  bg "$TMP/_bg.png"
  convert "$EN/$2" -filter point -resize 560x350! -bordercolor "$DIM" -border 2 "$TMP/_l.png"
  convert "$SHOT/$3" -filter point -resize 560x350! -bordercolor "$ACCENT" -border 2 "$TMP/_r.png"
  convert "$TMP/_bg.png" "$TMP/_l.png" -geometry +58+185 -composite \
    "$TMP/_r.png" -geometry +$((W-58-564))+185 -composite \
    -font "$FR" -fill "$DIM"   -gravity northwest -pointsize 32 -annotate +58+120 "$4" \
    -font "$FR" -fill "$ACCENT" -gravity northeast -pointsize 32 -annotate +58+120 "$5" \
    -font "$FB" -fill "$ACCENT" -gravity north -pointsize 30 -annotate +0+590 "$6" "$1"
}

clip() { # $1 png  $2 mp4  $3 秒
  local FO; FO=$(awk "BEGIN{print $3-0.6}")
  ffmpeg -y -loglevel error -loop 1 -i "$1" -t "$3" -r $FPS \
    -vf "fade=t=in:st=0:d=0.6,fade=t=out:st=$FO:d=0.6,format=yuv420p" \
    -threads 2 -c:v libx264 -preset veryfast -pix_fmt yuv420p "$2"
}

# ===== 分鏡 =====
card "$TMP/01.png" '亞瑟王傳奇' '尋找聖杯　繁體中文化' 'Conquests of Camelot: The Search for the Grail　·　Sierra On-Line, 1990'
slide_full  "$TMP/02.png" n_r100.png '不列顛在你手中統一了，好日子卻沒有跟著來。'
slide_frame "$TMP/03.png" n_r30.png  '旱象蔓延，疫病四起，人民在你的城牆外挨餓。'
slide_frame "$TMP/04.png" n_r180.png '高文、葛拉漢、蘭斯洛特先後出發尋訪聖杯，至今下落不明。'
slide_frame "$TMP/05.png" n_r45.png  '詛咒從哪裡來，你心裡清楚。沒有人能代你去。'
slide_full  "$TMP/06.png" n_r55.png  '穿過派瑞樂斯森林，渡過地中海，一路走到耶路撒冷的城門下。'
dcard "$TMP/07.png" '我通過了精神、肉體和智慧的考驗，\n看著昆海兒和蘭斯洛特兩人，\n肯萊特是痊癒了，而我的心呢？' '—— 1990《軟體世界》第 19 期〈尋找聖杯回憶錄〉'
slide_frame "$TMP/08.png" n_r60.png '4554 則對白與敘述、選單、道具欄，全部繁體中文。'
split_ba "$TMP/09.png" menu_02_menu_x40.png n_r100.png '英文原版' '繁體中文化' '譯名沿用 1990 年《軟體世界》攻略：肯萊特　昆海兒　葛拉漢　米夏拉'
card "$TMP/10.png" '倚天點陣字' '對白 24×24　選單 16×15　不是現代字型縮小的' '音樂走 Roland MT-32，當年廣告就把它列為賣點'
card "$TMP/11.png" '免費開源' 'Linux　Windows　macOS　只有引擎 patch，不含遊戲' 'github.com/wicanr2/conquests-of-camelot-cht'

LIST="$TMP/list.txt"; : > "$LIST"
i=1
for f in 01 02 03 04 05 06 07 08 09 10 11; do
  case "$f" in
    01|11) S=7 ;;
    07)    S=8 ;;
    *)     S=6 ;;
  esac
  clip "$TMP/$f.png" "$TMP/c_$f.mp4" $S
  echo "file '$TMP/c_$f.mp4'" >> "$LIST"
done

ffmpeg -y -loglevel error -f concat -safe 0 -i "$LIST" -threads 2 \
  -c:v libx264 -preset veryfast -pix_fmt yuv420p "$TMP/silent.mp4"

DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$TMP/silent.mp4")
FO=$(awk "BEGIN{print $DUR-3}")
# 原版 MT-32 側錄的標題曲。mean_volume -29.6dB 偏小 → 提 8dB 再鋪。
ffmpeg -y -loglevel error -i "$TMP/silent.mp4" -i /music/title_mt32.wav \
  -filter_complex "[1:a]volume=8dB,aloop=loop=-1:size=2000000000,atrim=0:$DUR,afade=t=in:st=0:d=2,afade=t=out:st=$FO:d=3[a]" \
  -map 0:v -map "[a]" -threads 2 -c:v libx264 -preset veryfast -c:a aac -b:a 192k \
  -movflags +faststart "$OUT/camelot-cht-promo.mp4"

echo "== 產出 =="
ffprobe -v error -select_streams v -show_entries stream=width,height,duration -of default=nw=1 "$OUT/camelot-cht-promo.mp4"
ffprobe -v error -select_streams a -show_entries stream=duration -of default=nw=1 "$OUT/camelot-cht-promo.mp4"
ls -la "$OUT/camelot-cht-promo.mp4"
