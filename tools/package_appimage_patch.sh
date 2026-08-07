#!/usr/bin/env bash
# patch 版 AppImage：只有 patched ScummVM ＋ 中文資料，**不含任何遊戲資源、不含 MT-32 ROM**。
# 這個版本是要上 GitHub Release 的，所以交付政策比 full 版嚴格：
#   - game/ 一個位元組都不放
#   - MT-32 ROM 有版權，不附、也不設 mt32 預設（無 ROM 又設 mt32 會彈一次阻擋框再回退 AdLib）
#
# 玩家自備正版遊戲，啟動後用 ScummVM 的 Add Game 指到遊戲目錄即可。
# 中文資料靠 SCI_CHT_DATA 指向包內的 cht-data/，玩家不必複製檔案。
# [HARD] 不能只用 --extrapath：實測 CLI 的 --extrapath 只有在「直接啟動」
# （--path + --auto-detect）時生效，玩家 Add Game 產生 target 之後從 launcher
# 按 Start，那條路徑上會被忽略 → 整個遊戲跑成英文（github issue #1）。
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "$ROOT/.." && pwd)"

STAGE="$ROOT/build/appimg-patch"
DIST="$ROOT/out/release"
APPDIR="$STAGE/AppDir"
# [HARD] Release 資產檔名只能用 ASCII——GitHub 上傳會把中文字整段剝掉
OUT="$DIST/CAMELOT-CHT-patch-x86_64.AppImage"

mkdir -p "$DIST"
rm -rf "$APPDIR"; mkdir -p "$APPDIR/usr/bin" "$APPDIR/usr/lib" "$APPDIR/usr/share/cht-data"

echo ">> 複製 scummvm + strip"
cp "$ROOT/scummvm-src/scummvm" "$APPDIR/usr/bin/scummvm"
docker run --rm --name cam-pkgp-strip -v "$APPDIR/usr/bin:/b" cam-build:latest strip /b/scummvm 2>/dev/null || true

echo ">> 收集共享庫"
docker run --rm --name cam-pkgp-libs \
  -v "$APPDIR/usr/bin/scummvm:/collect/bin:ro" \
  -v "$APPDIR/usr/lib:/collect/out" \
  -v "$ROOT/tools/pkg_collect_libs.py:/collect/collect.py:ro" \
  -w /collect cam-build:latest python3 collect.py bin out
echo "   $(ls "$APPDIR/usr/lib" | wc -l) 個 .so"

echo ">> 放入中文資料（只有 dist-cht/，不含遊戲資源）"
cp "$ROOT/dist-cht/"* "$APPDIR/usr/share/cht-data/"
ls "$APPDIR/usr/share/cht-data/"

cat > "$APPDIR/AppRun" <<'APPRUN'
#!/bin/bash
HERE="$(dirname "$(readlink -f "$0")")"
export LD_LIBRARY_PATH="$HERE/usr/lib:${LD_LIBRARY_PATH:-}"
# SCI_CHT_DATA 由引擎自己加進 SearchMan，不受 ScummVM 啟動路徑差異影響。
# --extrapath 與 --language 一併保留：直接啟動的情境仍走得通，也讓 MT-32 ROM 找得到。
export SCI_CHT_DATA="$HERE/usr/share/cht-data"
exec "$HERE/usr/bin/scummvm" --extrapath="$HERE/usr/share/cht-data" --language=tw "$@"
APPRUN
chmod +x "$APPDIR/AppRun"

cat > "$APPDIR/camelot-cht.desktop" <<'DESK'
[Desktop Entry]
Type=Application
Name=亞瑟王傳奇 尋找聖杯（繁體中文化）
Comment=Conquests of Camelot: The Search for the Grail 繁中化 — 需自備遊戲
Exec=AppRun
Icon=camelot-cht
Categories=Game;
Terminal=false
DESK
cp "$ROOT/tools/assets/camelot-cht.png" "$APPDIR/camelot-cht.png"
ln -sf camelot-cht.png "$APPDIR/.DirIcon"

rm -f "$OUT"
echo ">> appimagetool 打包"
docker run --rm --name cam-pkgp-tool -v "$STAGE:/stage" -v "$ROOT/tools/.cache:/cache:ro" -e ARCH=x86_64 -w /stage \
  cam-build:latest bash -c "apt-get update -qq >/dev/null && apt-get install -y -qq file >/dev/null && \
    /cache/appimagetool-x86_64.AppImage --appimage-extract-and-run 'AppDir' '/stage/$(basename "$OUT")'"
mv "$STAGE/$(basename "$OUT")" "$OUT"
docker run --rm -v "$DIST:/d" cam-build:latest chown -R 1000:1000 /d
chmod +x "$OUT"
echo ">> 完成: $OUT ($(du -h "$OUT" | cut -f1))"
