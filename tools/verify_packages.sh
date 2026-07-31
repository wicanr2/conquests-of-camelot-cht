#!/usr/bin/env bash
# 檢查每個包裡的中文資料與 dist-cht/ 逐檔 md5 相同，**而且沒有缺件**。
#
# [HARD] 要用 dist-cht/ 的清單去反查，不能只比對「包裡找到的檔案」——
# 只比對找到的，等於新增一種資料而打包腳本忘了加時它照樣印 ✓。
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST_CHT="$ROOT/dist-cht"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fail=0

expected=()
while IFS= read -r f; do expected+=("$(basename "$f")"); done < <(find "$DIST_CHT" -maxdepth 1 -type f | sort)
echo "dist-cht/ 應有 ${#expected[@]} 個檔：${expected[*]}"
echo

check_dir() {   # $1 = 包名  $2 = 解開後含中文資料的目錄
  local name="$1" dir="$2" miss=0
  for f in "${expected[@]}"; do
    local found
    found="$(find "$dir" -name "$f" -type f | head -1)"
    if [ -z "$found" ]; then
      echo "  ✗ 缺件：$f"; miss=1; fail=1; continue
    fi
    local a b
    a="$(md5sum "$DIST_CHT/$f" | cut -d' ' -f1)"
    b="$(md5sum "$found" | cut -d' ' -f1)"
    if [ "$a" != "$b" ]; then
      echo "  ✗ md5 不符：$f"; miss=1; fail=1
    fi
  done
  [ $miss -eq 0 ] && echo "  ✓ $name：${#expected[@]} 個中文資料檔全部到齊且一致"
}

for app in "$ROOT/out/release"/*.AppImage "$ROOT/../dist-all"/*.AppImage; do
  [ -f "$app" ] || continue
  echo "=== $(basename "$app") ==="
  rm -rf "$TMP/x"; mkdir -p "$TMP/x"
  (cd "$TMP/x" && "$app" --appimage-extract >/dev/null 2>&1) || { echo "  ✗ 無法解開"; fail=1; continue; }
  check_dir "$(basename "$app")" "$TMP/x"
done

for z in "$ROOT/out/release"/*.zip "$ROOT/../dist-all"/*.zip; do
  [ -f "$z" ] || continue
  echo "=== $(basename "$z") ==="
  rm -rf "$TMP/z"; mkdir -p "$TMP/z"
  unzip -q -o "$z" -d "$TMP/z" || { echo "  ✗ 無法解開"; fail=1; continue; }
  check_dir "$(basename "$z")" "$TMP/z"
done

for t in "$ROOT/out/release"/*.tar.gz "$ROOT/../dist-all"/*.tar.gz; do
  [ -f "$t" ] || continue
  echo "=== $(basename "$t") ==="
  rm -rf "$TMP/t"; mkdir -p "$TMP/t"
  tar xzf "$t" -C "$TMP/t" || { echo "  ✗ 無法解開"; fail=1; continue; }
  check_dir "$(basename "$t")" "$TMP/t"
done

echo
[ $fail -eq 0 ] && echo "全部通過" || echo "有問題，見上"
exit $fail
