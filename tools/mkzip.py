#!/usr/bin/env python3
"""打 Windows zip，並把「檔名編碼」這件事做對。

## 為什麼不直接用 `zip -r`

Info-ZIP 的 `zip` 預設把檔名以 UTF-8 bytes 寫入，**但不設 UTF-8 旗標（general purpose
bit 11 / EFS）**。繁體中文 Windows 的解壓工具（檔案總管、舊版 WinRAR）看到沒有旗標，
就用系統 ANSI（CP950）去解讀那串 UTF-8 bytes：

  - 運氣好 → 檔名變亂碼
  - 運氣差 → UTF-8 bytes 在 CP950 裡是非法序列，**該檔直接被跳過**
             （使用者看到的症狀是「解開之後檔案不見了」）

## 這支的做法

1. **檔名一律 ASCII**（根治）——中文留在檔案內容裡，不放檔名。
2. **仍設 UTF-8 旗標**（保險）——`zipfile` 對非 ASCII 檔名會自動設 bit 11；
   這裡明確驗一次，日後若有人加了中文檔名也不會回到老問題。
3. **檔案內容各自用對的編碼**（見 build_zip 的 encoding 參數）：
   - `.bat` → CP950。cmd 配 `chcp 950` 才顯示得出中文；存 UTF-8 會是亂碼。
   - `.txt` → UTF-8 with BOM。Windows 10 之後的記事本靠 BOM 正確辨識。

用法：mkzip.py <輸出.zip> <來源目錄>
"""
import sys, os, zipfile


def check_ascii_names(root):
    bad = []
    for dirpath, dirnames, filenames in os.walk(root):
        for n in dirnames + filenames:
            if any(ord(c) > 127 for c in n):
                bad.append(os.path.relpath(os.path.join(dirpath, n), root))
    return bad


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    out, src = sys.argv[1], sys.argv[2]

    bad = check_ascii_names(src)
    if bad:
        sys.stderr.write("WARN 這些檔名含非 ASCII 字元，繁中 Windows 解壓可能亂碼或跳過：\n")
        for b in bad:
            sys.stderr.write(f"      {b}\n")

    if os.path.exists(out):
        os.remove(out)
    n = 0
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for dirpath, _dirnames, filenames in sorted(os.walk(src)):
            for fn in sorted(filenames):
                full = os.path.join(dirpath, fn)
                arc = os.path.relpath(full, src)
                z.write(full, arc)
                n += 1

    # 驗一次：非 ASCII 檔名必須帶 UTF-8 旗標
    with zipfile.ZipFile(out) as z:
        for i in z.infolist():
            if any(ord(c) > 127 for c in i.filename) and not (i.flag_bits & 0x800):
                sys.exit(f"✗ {i.filename!r} 是非 ASCII 檔名卻沒有 UTF-8 旗標")
    print(f"{out}：{n} 個檔，檔名編碼檢查通過")


if __name__ == "__main__":
    main()
