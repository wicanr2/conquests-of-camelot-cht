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

# 包內的中文檔名不受 Release ASCII 限制
cat > "$STAGE/玩-亞瑟王傳奇-繁中.bat" <<'BAT'
@echo off
chcp 950 >nul
cd /d "%~dp0"
rem 第一次執行請先用 ScummVM 的「Add Game」把遊戲目錄加進來。
rem --extrapath 讓引擎找到中文資料，不必把檔案複製進遊戲目錄。
scummvm.exe --extrapath="%~dp0cht-data" --language=tw
BAT

cat > "$STAGE/讀我.txt" <<'TXT'
亞瑟王傳奇 尋找聖杯（Conquests of Camelot: The Search for the Grail）繁體中文化
Windows x86_64 — patch 版（不含遊戲）

這個包只有中文化過的 ScummVM 與中文資料，**不含遊戲本身**。
你需要自備正版《Conquests of Camelot》(1990, DOS)。

怎麼玩：
  1. 雙擊「玩-亞瑟王傳奇-繁中.bat」
  2. 在 ScummVM 畫面按「Add Game...」，選到你的遊戲目錄（裡面有 RESOURCE.MAP 那個）
  3. 選中遊戲，按 Start

中文資料在 cht-data/，由 .bat 的 --extrapath 帶進去，不必複製到遊戲目錄。

想用 Roland MT-32 音源（音色遠優於 AdLib，也是這一作當年的設計音源）：
  MT-32 ROM 有版權，本包不附。自備 MT32_CONTROL.ROM 與 MT32_PCM.ROM 之後，
  放進 cht-data/，再到 ScummVM 的音效選項選 Roland MT-32。

內容物：
  scummvm.exe                       patched ScummVM（Big5 中文繪字 + MT-32 音源模擬）
  SDL2.dll / libwinpthread-1.dll    執行所需 runtime
  cht-data/                         譯文表與倚天點陣中文字型

原始碼與說明：https://github.com/wicanr2/conquests-of-camelot-cht
TXT

rm -f "$OUT"
echo ">> zip 打包"
( cd "$STAGE" && zip -qr "$OUT" . )
docker run --rm -v "$DIST:/d" cam-build:latest chown -R 1000:1000 /d 2>/dev/null || true
echo ">> 完成: $OUT ($(du -h "$OUT" | cut -f1))"
