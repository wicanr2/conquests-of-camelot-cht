#!/usr/bin/env bash
# 交付政策稽核：
#   full 包  → **必須**含遊戲資源（否則玩家開箱不能玩）
#   patch 包 → **必不可**含任何遊戲資源或 MT-32 ROM（要上 GitHub Release，含了就是散布版權物）
#
# 判斷依據是實際檔案，不是檔名——包名叫 patch 但裡面有 resource.001 一樣要擋下來。
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fail=0

# 遊戲資源的特徵檔（本作 1990 SCI0 EGA）
GAME_PAT='resource\.(map|00[0-9])$|sciv\.exe$|^version$'
ROM_PAT='\.ROM$'

audit() {  # $1 = 包路徑  $2 = full|patch
  local pkg="$1" kind="$2" dir="$TMP/a"
  rm -rf "$dir"; mkdir -p "$dir"
  case "$pkg" in
    *.AppImage) (cd "$dir" && "$pkg" --appimage-extract >/dev/null 2>&1) ;;
    *.zip)      unzip -q -o "$pkg" -d "$dir" ;;
    *.tar.gz)   tar xzf "$pkg" -C "$dir" ;;
  esac
  local ngame nrom
  ngame=$(find "$dir" -type f | grep -icE "$GAME_PAT" || true)
  nrom=$(find "$dir" -type f | grep -cE "$ROM_PAT" || true)
  echo "=== $(basename "$pkg")  [$kind] ==="
  echo "    遊戲資源檔 $ngame 個、ROM $nrom 個"
  if [ "$kind" = "full" ]; then
    if [ "$ngame" -eq 0 ]; then echo "    ✗ full 包應含遊戲資源卻沒有"; fail=1
    else echo "    ✓ 含遊戲資源（符合 full 包定義）"; fi
  else
    if [ "$ngame" -gt 0 ]; then
      echo "    ✗ patch 包含有遊戲資源——**不可上 Release**："
      find "$dir" -type f | grep -iE "$GAME_PAT" | sed 's|^|        |' | head -5
      fail=1
    elif [ "$nrom" -gt 0 ]; then
      echo "    ✗ patch 包含有 MT-32 ROM（有版權）："
      find "$dir" -type f | grep -E "$ROM_PAT" | sed 's|^|        |'
      fail=1
    else
      echo "    ✓ 不含遊戲資源、不含 ROM（可上 Release）"
    fi
  fi
}

for p in "$ROOT/out/release"/*; do
  [ -f "$p" ] || continue
  audit "$p" patch
done
for p in "$ROOT/../dist-all"/*; do
  [ -f "$p" ] || continue
  audit "$p" full
done

echo
[ $fail -eq 0 ] && echo "交付政策稽核通過" || echo "稽核失敗，見上"
exit $fail
