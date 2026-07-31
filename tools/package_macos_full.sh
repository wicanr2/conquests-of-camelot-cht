#!/usr/bin/env bash
# macOS **full 版**：CI 只產 patch 版（engine + 中文資料），這支把遊戲資源與 MT-32 ROM
# 注入進去，做成本機用的完整包。
#
# [雷] 這一格是六個包裡最常被忘記的——它不是 CI 產的，要多一道「下載 artifact → 本機注入」。
#
# 前置：先把 CI 的 artifact 下載並解開，例如
#   gh run download <run-id> -n CAMELOT-CHT-patch-macos-universal -D /tmp/macos-art
# 然後：
#   MACOS_PATCH_TGZ=/tmp/macos-art/CAMELOT-CHT-patch-macos-universal.tar.gz bash tools/package_macos_full.sh
#
# ⚠ Linux 端無法代簽也無法實測 macOS 執行檔；玩家端要先跑包內的「修復-macOS.command」
#   解除 Gatekeeper 隔離。
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "$ROOT/.." && pwd)"
source "$ROOT/tools/pkg_common.sh"

TGZ="${MACOS_PATCH_TGZ:?請用 MACOS_PATCH_TGZ=<CI 下載的 patch tar.gz> 指定來源}"
STAGE="$ROOT/build/macos-full"
DIST="$REPO_ROOT/dist-all"
OUT="$DIST/CAMELOT-CHT-full-macos-universal.tar.gz"

[ -f "$TGZ" ] || { echo "!! 找不到 $TGZ"; exit 1; }
mkdir -p "$DIST"
rm -rf "$STAGE"; mkdir -p "$STAGE"

echo ">> 解開 CI 的 patch 包"
tar xzf "$TGZ" -C "$STAGE"
APP="$STAGE/CAMELOT-CHT"
[ -d "$APP" ] || { echo "!! 解開後找不到 CAMELOT-CHT/"; exit 1; }

echo ">> 注入遊戲資源"
mkdir -p "$APP/game"
cp -r "$ROOT/game/." "$APP/game/"

MT32NOTE=""
if stage_mt32_rom "$APP/game"; then
  MT32NOTE=" --music-driver=mt32"
fi

# full 版的啟動器直接指向內嵌遊戲，玩家不必 Add Game
cat > "$APP/啟動.command" <<RUNEOF
#!/bin/bash
cd "\$(dirname "\$0")"
./scummvm --path="\$PWD/game" --extrapath="\$PWD/cht-data" --language=tw --auto-detect$MT32NOTE "\$@"
RUNEOF
chmod +x "$APP/啟動.command"

rm -f "$OUT"
tar czf "$OUT" -C "$STAGE" CAMELOT-CHT
echo ">> 完成: $OUT ($(du -h "$OUT" | cut -f1))"
echo ">> 提醒：full 包含遊戲資源與 ROM，**只放本機 dist-all/，不上 GitHub**"
