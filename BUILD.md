# 亞瑟王傳奇 繁中化 — Build 手冊

拿到 `patches/` + `docker/` + `tools/` + `dist-cht/` 就能重建整套。原始遊戲資源與
上游 ScummVM 原始碼都不在庫裡，照下面步驟取。

## 0. 取原始碼並套 patch

1. 取乾淨 ScummVM 原始碼，checkout `patches/UPSTREAM_COMMIT.txt` 記的 pinned commit
   （版本差太多 patch 會套不上）。

   ```bash
   git clone https://github.com/scummvm/scummvm.git scummvm-src
   git -C scummvm-src checkout $(cat patches/UPSTREAM_COMMIT.txt)
   ```

2. 套中文化引擎改動：

   ```bash
   tools/apply_patches.sh scummvm-src
   ```

   會複製 `engines/sci/graphics/fontchinese.{h,cpp}`（`GfxFontChinese`：Big5 繪字 +
   hi-res 24×24 loader），並套 `patches/0001-sci-cht-zh_twn.patch`（ZH_TWN 啟用、
   640×400 hi-res、kFormat 動態句 hook、`GetLongest` Big5 斷行修正、空白正規化 key、
   `SCI_DUMP_RES` 抽字 hook、標題疊圖 hook）。

## 1. Linux（x86_64）

```bash
docker build -t cam-build -f docker/Dockerfile.build .
docker run --rm --name cam-build -v "$PWD/scummvm-src:/src" -w /src cam-build bash -c \
  "./configure --disable-all-engines --enable-engine=sci --disable-detection-full && make -j\$(nproc)"
```

**[HARD] configure 順序**：`--disable-all-engines` 必須在 `--enable-engine=sci` **之前**
（反了 sci 引擎會被關掉）。

**[HARD] 不要帶 `--disable-mt32emu`**。當年的廣告就把 MT-32 列為賣點，遊戲也內附 `MT32.DRV`
——MT-32 是這一作本來就設計好的音源。編完驗證：

```bash
grep USE_MT32EMU scummvm-src/config.h   # 應為 #define
```

**[HARD] docker 產出的檔案 owner 是 root**，每個 docker 步驟收尾補：

```bash
docker run --rm -v "$PWD/scummvm-src:/x" cam-build chown -R 1000:1000 /x
```

## 2. 產中文資料

```bash
bash tools/build_translation.sh
```

流程：合併 `translation/done/*.done` → 套 `converge.tsv` 全域收斂 →
`build_cht.py` 產 16×15 字型與 Big5 runtime 表 → `bake_hires_eten.py` 產 24×24 hi-res 字型
→ 輸出到 `dist-cht/` 並複製進 `game/`。

產物三個（引擎讀寫死檔名）：

```
translation.tsv        英文原文 <TAB> Big5 譯文
camelot_big5.fnt       16×15 低解析（選單）
camelot_big5_hi.fnt    24×24 hi-res（對白）
```

### 字形來源：倚天中文系統，不是 TTF

字型檔在 `art/fonts/`，從倚天 3.53 光碟取出：

| 檔案 | 用途 | 備註 |
|---|---|---|
| `STDFONT.15` | 16×15 漢字 13094 字 | 裸格式 |
| `SPCFONT.15` | 16×15 全形符號 408 字 | **[雷] 漏帶會讓 ，。！？「」 全部掉 fallback** |
| `STDFONT.24` | 24×24 漢字 | 由 `tools/etunpack.py` 解 `STD.24M` 而來 |
| `SPCFONT.24` | 24×24 全形符號 | 裸格式 |

**動索引公式前先跑 oracle 自驗**（`idx=0` 必須是「一」）：

```bash
python3 tools/eten_font.py        # 16×15
python3 tools/eten_font.py --24   # 24×24
```

這關沒過的話整批字會整體偏移，症狀是「有字但全都不對」。

### [HARD] 引擎常數與烘字尺寸必須一致

```
fontchinese.cpp     kHiW = 24   kHiH = 24   kBig5WidthHi = 12
bake_hires_eten.py              24×24
```

不一致 → 引擎逐字讀錯位，畫面上中文字互相重疊。**改任一邊都要同步改另一邊。**

## 3. 執行

```bash
./scummvm --path=<game-dir> --auto-detect --language=tw
```

SCI0 用 CLI `--language=tw` 即可（SCI1 才要寫進 target config，別混）。
`dist-cht/` 三個檔要放在遊戲目錄，或用 `--extrapath` 指過去。

## 4. 檢查工具（三道都要跑，都不充分）

```bash
python3 tools/validate_batch.py translation/batch/bNN.tsv translation/done/bNN.done
python3 tools/scan_zh.py translation/done/*.done
python3 tools/scan_consistency.py translation/translation_utf8.tsv
```

| 工具 | 抓什麼 |
|---|---|
| `validate_batch.py` | 行數、英文 key 逐 byte、控制序列、Big5 可編 |
| `scan_zh.py` | 簡體字、兩岸共用碼誤用（后／裡／麵／製）、中國大陸用語 |
| `scan_consistency.py` | 譯名漂移（獨立批次之間） |

**三支都測不到語意層的錯**（因果講反、指涉不明、謎語在中文無解）——那只能靠人工抽樣與實機。

## 5. headless 實機擷取

```bash
docker build -t cam-capture -f docker/Dockerfile.capture .
docker run --rm --name cam-cap -v "$PWD/scummvm-src:/src" -v "$PWD/game:/game:ro" \
  -v "$PWD/out:/out" -v "$PWD/tools:/tools:ro" -e EXTRA="--language=tw" \
  cam-capture bash /tools/capture_ingame.sh
```

- **[雷] `xdotool key --window` 對 SDL2 無效**（走 XSendEvent，SDL2 忽略合成事件）。
  要先 `windowactivate` 再送不帶 `--window` 的 XTEST 事件；`type` 要加 `--delay 120`。
- **[雷] 開場的「Camelot Game Options」選單 Escape 與 Tab 都無效，只吃滑鼠點擊**，
  而且出現時機會浮動（credits 輪播中才疊上來）→ 別用固定 sleep，重複點到進去為止。
- **[雷] `SCI_DUMP_RES` 跑完會 segfault**，但 dump 內容完整，不是引擎壞掉。
- docker run 一律用 `timeout` 包，收尾 `pkill -f scummvm`。

## 6. 重生 patch（改了引擎之後）

`tools/regen_patch.sh`：從 pinned upstream 抓 pristine 逐檔 diff，重生
`patches/0001-sci-cht-zh_twn.patch`，並以 `patch -p1 --dry-run` 驗證可乾淨套用。

## 7. Windows / macOS

- **Windows**：mingw 交叉編譯（`docker/Dockerfile.mingw`）。
  **[雷] 同步 source 樹別用 `cp -a`** —— 本機 Linux 編過的樹裡有 ELF 的 `.o/.d/.dwo`，
  整包複製會用 ELF 物件檔蓋掉 mingw 的同名物件，產生幾百條 `undefined reference`，
  看起來像原始碼壞了，其實是物件檔架構不符。只複製 `*.cpp`/`*.h`，
  且**別排除 `config.guess`/`config.sub`**（否則 configure 判不出 endianness）。
- **macOS**：只能在 macOS host build，走 GitHub Actions `macos-14`。
  **[雷] 別 `brew install sdl2`**（2026-06 起是 sdl2-compat shim，打包抓不到 → 玩家端黑畫面），
  要自源碼編 pinned 真 SDL2，universal 用「每弧各編 + `lipo -create`」。
  **[雷] macOS 只有 bash 3.2**，避開 `${VAR^^}`、`declare -A`、`mapfile` 這些 bash 4+ 語法。
  **[雷] clang 的 `\x` 會貪婪吃後續 hex 字元** → 引擎裡硬寫的 Big5 字面值要用
  `"\xA1\x41" "ESC"` 這種串接方式打斷。
