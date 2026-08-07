#!/usr/bin/env bash
# patch 版 Windows zip：只有 scummvm.exe + runtime DLL + 中文資料。
# **不含遊戲資源、不含 MT-32 ROM**（要上 GitHub Release）。
# 前置：先跑 mingw build 產出 build/mingw-tree/scummvm.exe（見 BUILD.md）。
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

MINGW_IMG="${MINGW_IMG:-sq1-mingw}"
EXE="$ROOT/build/mingw-tree/scummvm.exe"
STAGE="$ROOT/build/win64-patch"
DIST="$ROOT/out/release"
# [HARD] Release 資產檔名只能用 ASCII——GitHub 上傳會把中文字整段剝掉
OUT="$DIST/CAMELOT-CHT-patch-win64.zip"

[ -f "$EXE" ] || { echo "!! 找不到 $EXE（先跑 mingw build）"; exit 1; }

mkdir -p "$DIST"
rm -rf "$STAGE"; mkdir -p "$STAGE/cht-data"

echo ">> 複製 scummvm.exe + strip"
cp "$EXE" "$STAGE/scummvm.exe"
docker run --rm --name cam-winp-strip -v "$STAGE:/s" "$MINGW_IMG" x86_64-w64-mingw32-strip /s/scummvm.exe

echo ">> 收集 runtime DLL"
docker run --rm --name cam-winp-sdl "$MINGW_IMG" cat /usr/x86_64-w64-mingw32/bin/SDL2.dll > "$STAGE/SDL2.dll"
docker run --rm --name cam-winp-pth "$MINGW_IMG" cat /usr/x86_64-w64-mingw32/lib/libwinpthread-1.dll > "$STAGE/libwinpthread-1.dll"

echo ">> 放入中文資料（只有 dist-cht/，不含遊戲資源）"
cp "$ROOT/dist-cht/"* "$STAGE/cht-data/"
ls "$STAGE/cht-data/"

# [HARD] 包**內**的檔名也要用 ASCII。zip 的檔名沒有編碼欄位，Info-ZIP 寫 UTF-8 bytes
# 卻不設 UTF-8 旗標，繁中 Windows 的解壓工具會用 CP950 去解讀 → 亂碼，或因為是非法
# byte 序列**直接跳過該檔**（症狀是「解開之後檔案不見了」）。中文留在檔案內容裡。
# .bat 內容存 CP950：cmd 配 chcp 950 才顯示得出中文，存 UTF-8 會是亂碼。
python3 - "$STAGE/PLAY-CAMELOT-CHT.bat" <<'PYBAT'
import sys
open(sys.argv[1], 'w', encoding='cp950', newline='\r\n').write("""@echo off
chcp 950 >nul
cd /d "%~dp0"
echo 亞瑟王傳奇 尋找聖杯 繁體中文化
echo.
echo 第一次執行請先按 Add Game，選到你的遊戲目錄（裡面有 RESOURCE.MAP 那個）。
echo 中文資料由啟動器帶進去，不必複製任何檔案到遊戲目錄。
echo.
set SCI_CHT_DATA=%~dp0cht-data
scummvm.exe --extrapath="%~dp0cht-data" --language=tw
""")
PYBAT

# .txt 存 UTF-8 with BOM：Windows 10 之後的記事本靠 BOM 正確辨識中文
# .txt 存 UTF-8 with BOM：Windows 10 之後的記事本靠 BOM 正確辨識中文。
# 一次寫對，不要先 cat 再轉檔——中間那步很容易靜默失敗，而且產物看起來「檔案有在」。
python3 - "$STAGE/README-CHT.txt" <<'PYTXT'
import sys
open(sys.argv[1], 'w', encoding='utf-8-sig', newline='\r\n').write('''亞瑟王傳奇 尋找聖杯（Conquests of Camelot: The Search for the Grail）繁體中文化
Windows x86_64 — patch 版（不含遊戲）

這個包只有中文化過的 ScummVM 與中文資料，**不含遊戲本身**。
你需要自備正版《Conquests of Camelot》(1990, DOS)。

怎麼玩：
  1. 雙擊 PLAY-CAMELOT-CHT.bat
  2. 在 ScummVM 畫面按「Add Game...」，選到你的遊戲目錄（裡面有 RESOURCE.MAP 那個）
  3. 選中遊戲，按 Start

中文資料在 cht-data/，由 .bat 帶進去（SCI_CHT_DATA），不必複製到遊戲目錄。

想用 Roland MT-32 音源（音色遠優於 AdLib，也是這一作當年的設計音源）：
  MT-32 ROM 有版權，本包不附。自備 MT32_CONTROL.ROM 與 MT32_PCM.ROM 之後，
  放進 cht-data/，再到 ScummVM 的音效選項選 Roland MT-32。

內容物：
  PLAY-CAMELOT-CHT.bat              啟動器（檔名用英文是為了避開 zip 的檔名編碼問題）
  scummvm.exe                       patched ScummVM（Big5 中文繪字 + MT-32 音源模擬）
  SDL2.dll / libwinpthread-1.dll    執行所需 runtime
  cht-data/                         譯文表與倚天點陣中文字型

原始碼與說明：https://github.com/wicanr2/conquests-of-camelot-cht
''')
PYTXT
echo ">> zip 打包（檔名全 ASCII + UTF-8 旗標，見 tools/mkzip.py）"
python3 "$ROOT/tools/mkzip.py" "$OUT" "$STAGE"
docker run --rm -v "$DIST:/d" cam-build:latest chown -R 1000:1000 /d 2>/dev/null || true
echo ">> 完成: $OUT ($(du -h "$OUT" | cut -f1))"
