# 亞瑟王傳奇 中文化 — 專案脈絡

> 本檔記錄**已驗證的事實**與**術語**。規劃與守則在上層 `../CLAUDE.md`；
> 斷言任何「已完成／不存在」之前，先看 code 與實測結果，別信過期敘述。

## 一、引擎與版本（已驗證，2026-08-01）

| 項目 | 值 | 證據 |
|---|---|---|
| 引擎 | **SCI0**（SCI interpreter 0.000.685） | ScummVM `detection_tables.h` 條目註解 ＋ 遊戲 `version` 檔 `1.001.000` |
| ScummVM game ID | `camelot`，target `sci:camelot` | 實機偵測輸出「Conquests of Camelot: King Arthur, Quest for the Grail (DOS/English)」 |
| 偵測條目語言 | `Common::EN_ANY`, `kPlatformDOS` | 同上表第 464 行「English DOS (from jvprat)」 |
| 資源檔 | `resource.map`(7278) + `resource.001~004` | md5 與偵測表逐檔吻合 |
| 顯示 | EGA 320×200 / 16 色 | `resource.cfg` `videoDrv=EGA320.DRV` |

同 md5 的另一條目是俄文 fan translation，靠額外的 `Translate.RU` 檔區分——**本作目錄不得留下該檔**，
否則會被誤判成俄文版。

## 二、資源與字串規模（已驗證）

`SCI_DUMP_RES` 解壓後（`extract/res/`，812 檔）：

| 類型 | 檔數 |
|---|---|
| text | 190 |
| script | 226 |
| view | 288 |
| pic | 100 |
| font | 8 |

抽字結果：

| 來源 | 則數 |
|---|---|
| text/message | 4417 |
| script 內嵌 | 154 |
| **合計** | **4571 則，325571 英文字元** |

長度中位數 63 字元、最長 499、超過 200 字元者 44 則。

**[雷] `SCI_DUMP_RES` 跑完會 segfault**，但 dump 內容完整；不帶該環境變數跑則完全正常
（已用同一 binary 對照跑過）。不是引擎壞掉，別花時間追。

## 三、防拷（已驗證：無文字型防拷）

在**解壓後**的 `text.*` / `script.*` 與抽出的 4571 則字串中，
`manual` / `password` / `serial` / `copy protect` / `codeword` / `verify` **全部零命中**。
`disk` 只命中存檔磁片訊息（"Your save game disk is full."）。

依 CLAUDE.md ①-2 的紀律，這次的零命中是對**解壓後資源**做的，構成有效證據。
仍待 playtest 確認遊戲中段有無「對照包裝內附地圖／詞彙表」這類非文字型 gate。

## 四、開場流程（實機實測）

啟動 → Sierra logo → 標題（`Conquests of Camelot` logo ＋ 劍）→ credits 逐張輪播
→ **「Camelot Game Options」選單**（See the Intro / Start New Game / Restore Game）。

- **[雷] 這個選單只吃 `Return`，不吃 `xdotool click`**（2026-08-01 更正——先前這裡寫的
  「只吃滑鼠點擊」是錯的）。游標移到按鈕上、click 送出去，按鈕不會有任何反應；
  正確做法是 **`Return` 按兩次**：第一次把選單叫出來，第二次選中預設的「觀看片頭」。
  `tools/capture_ingame.sh` 的 `click 455 415` 是更早期版本的座標，現在點空——
  它當年之所以能進遊戲，其實是靠後面那幾個 `Escape` 與 `Return`。
- **[雷] Xvfb 沒有 window manager** → `xdotool windowactivate` 必定失敗
  （`_NET_ACTIVE_WINDOW` 不支援）。PointerRoot focus 模式下，先 `mousemove` 把游標移進視窗，
  XTEST 鍵盤事件才送得到。
- credits 會循環輪播（attract mode），不動作就一直跑；選單要等輪播跑一輪（約 26 秒）才疊上來。

## 五、漏抽字串（要補，隨查隨記）

| 字串 | 出現位置 | 狀態 |
|---|---|---|
| `Camelot Game Options:` | 開場選單標題 | **未抽到**，需另找來源 |

`See the Intro` / `Start New Game` / `Restore Game` 三顆按鈕**已在 skeleton 內**。

## 六、術語（glossary）

譯名表在 `translation/names.tsv`（英文＜TAB＞中文＜TAB＞依據），完整考據見
`docs/20-walkthrough-glossary.md`。三條硬規則：

1. **第一順位是《軟體世界》第 18、19 期攻略的譯名**（使用者 2026-08-01 指示）。
   該攻略體例是「中文（English）」，等於當年編輯已做過一輪對照表。
2. 攻略未收錄者取 1990 廣告頁；兩者皆無才查**通行中譯**，不自創音譯。
3. 待定項在定案前不得進入翻譯批次。

**[HARD] 廣告頁與攻略衝突時以攻略為準**：`Camelot` 廣告作「甘美特」、攻略作「**肯萊特**」→ 用肯萊特。

**遊戲用的是古拼法**，抽字與譯名對照時別按現代拼法找：

| 遊戲內拼法 | 現代拼法 | 中文 |
|---|---|---|
| `Gawaine` | Gawain | 高文 |
| `Launcelot` | Lancelot | 蘭斯洛特 |
| `Gwenhyver` | Guinevere | 昆海兒 |
| `Excaliber` | Excalibur | 聖劍 |

## 七、中文顯示（2026-08-01 實機驗證通過）

啟用方式：**只要 `translation.tsv` 在搜尋路徑上就啟用**（引擎自己判定，見第十二之二節）。
patch 版的啟動器用 `SCI_CHT_DATA=<cht-data 目錄>` 把資料交給引擎。
⚠ 早先這裡寫的「`--language=tw` 即可」**只在直接啟動時成立**，玩家從 launcher
啟動時無效——那是 issue #1 的根因。實機確認對白框中文正確斷行、標點正常、框會依中文長度自動加大。

### 字形：倚天 (ETEN 3.53) 原生點陣，非 TTF

| 用途 | 尺寸 | 來源 |
|---|---|---|
| hi-res 對白（640×400） | **24×24** | `STDFONT.24`（`etunpack.py` 解 `STD.24M`）+ `SPCFONT.24` |
| low-res（選單等） | 16×15 | `STDFONT.15` + `SPCFONT.15` |

字型檔在 `art/fonts/`，從 `/home/anr2/cht/etan_font/ET353S.iso` 取出。
`tools/eten_font.py` 有 oracle 自驗（`idx=0` 必須是「一」），**動索引公式前先跑它**。

### [HARD] 引擎常數與烘字尺寸必須一致

```
fontchinese.cpp   kHiW = 24   kHiH = 24   kBig5WidthHi = 12   （12×2 = 24 display px）
bake_hires_eten.py            24×24
```

**這個坑是從 kq4 繼承來的**：kq4 的 `fontchinese.cpp` 寫 `kHiW=20/kHiH=20`，
它的 `build_translation.sh` 卻烘 `24×22`，註解還寫「須對齊 kHiW=24/kHiH=22」——
三處互相矛盾。照抄過來的結果是引擎逐字讀錯位，**畫面上中文字互相重疊、糊成一團**
（看起來像「字型烘壞了」，其實是尺寸協議不一致）。改任一邊都要同步改另一邊。

## 八、[HARD] SCI 的外框字：中文兩趟畫同一套字模會整段消失

本作開場旁白（無框、直接畫在畫面上的白字）中文化後**整段幾乎看不見**，
但同一份字型在對話框裡完全正常——這個症狀花了幾輪才定位。

**根因**：SCI 用「兩個字型疊畫」做外框字——先用**實心遮罩字型**（本作是 `font.104`，
它的 `M` 是整塊實心）畫黑色，再用細字型（`font.103`）畫白色，疊出一圈黑邊。
引擎把每個 SCI 字型都換成 `GfxFontChinese` 之後，兩趟畫的是**同一套 Big5 字模**，
白色那趟完全蓋掉黑色那趟 → 外框消失 → 白字畫在白雲上等於看不見。

**為什麼難查**：字模本身是好的，畫面上看起來只像「字太淡／被裁掉」，
很容易誤判成字型烘壞或 display buffer 被重繪抹掉。
決定性的一步是**放大截圖看實際像素**——字形完整、只是白的，才排除掉字型問題。

**修法**（`fontchinese.cpp` `draw()` / `drawHiRes()`）：`color == 0`（黑色那一趟）時
把字模膨脹一圈。

**膨脹形狀後來改過**（2026-08-01，見下節）：hi-res 路徑最初用十字形（上下左右，不含對角），
理由是「中文筆劃只隔 2px，對角那幾點會把空隙補滿」。實機 A/B 之後推翻——**hi-res 24×24
的筆劃間距夠寬，3×3 不會糊，而十字形會讓外框在斜筆劃（撇／捺）上斷開**，
淺色背景（開場字幕疊在天空與白雲上）就是沿著那些缺口糊掉。現在預設 3×3，
`SCI_CHT_OUTLINE=cross` 可切回十字形做 A/B。低解析路徑（選單，深灰底）維持十字形。

**診斷開關**：`SCI_CHT_NOHIRES=1` 強制走低解析路徑，用來分辨
「hi-res 字模不對」與「有東西畫過去」。

## 八之二、開場字幕行距：行距等於字高就會糊成一團（2026-08-01）

做推廣片素材時才發現：開場字幕（無框、多行，疊在城堡遠景上）**上下行的筆劃互相咬到**，
整段幾乎讀不出來。對話框完全正常，所以先前逐場景 playtest 沒抓到。

**根因**是算術上的巧合。`getHeight()` 回傳 `_big5Height`（遊戲的 320×200 邏輯座標），
hi-res 路徑用 `dispTop = top * 2` 繪製，所以**一個邏輯單位 = 2 個顯示列**。
`_big5Height` 被 cap 到 **12** → 行距 24px，而 hi-res 字模剛好 `kHiH = 24` 列，
**行距等於字高，零留白**。倚天 24×24 的字模本身上下不留邊，於是相鄰兩行直接貼死。

**為什麼只有這裡看得出來**：對話框的行數少、又有框線與底色幫忙分隔，貼死只讀作「有點擠」；
無框的多行字幕疊在複雜背景上，缺了那 2px 就整段崩掉。

**修法**：cap 改成 **13**（行距 26px，上下留 2px）。改動要留意的是原本 cap 到 12 的用意
（`issue #1: 對話後面被截斷`）——實測對話框變高 2px 並未造成截斷。

**通則**：凡是「行距由一個被 cap 的值換算、而字模高度另外寫死」的字型實作，
**檢查 cap 後的行距是否嚴格大於字模高度**。兩者相等時單元測試與覆蓋率都正常，
只有多行無框文字會露餡。

## 九、標題疊圖：量測後決定不做

「Conquests of Camelot」標題畫面（`pic 110`，用 `SCI_LOG_GFX` 認出來的——
整個開場只畫兩張 pic：112 與 110，靠翻轉 gate 看疊圖落在哪張確認）**放不下中文**：

| 位置 | 淨空 | 結果 |
|---|---|---|
| 頂端 | 邏輯 y 0–9，**10 列** | 16×15 字模放不下，下半被紅色邊框蓋掉 |
| 劍下方（y 170） | 約 13 列 | 字的上半被劍的閃光動畫蓋掉 |
| logo 與劍之間 | 約 12 列 | 同樣不足 |

倚天最小字模是 **16×15**，加描邊 17 列。依 CLAUDE.md ⑦「硬塞的後果不是醜，
是蓋掉旁邊的東西」，這項不做。

**一開始的量測是錯的**：用「整列幾乎全空」當門檻量出頂端有 18 列，
但那條紅色邊框只佔畫面兩側與一條細線，沒有觸發門檻——**實際淨空只有 10 列**。
量可用空間要看「這塊矩形裡有沒有東西」，不是「這一列空不空」。

工具與引擎 hook 都留著（`tools/build_title_overlay_eten.py`、`paint16.cpp` 的
`drawChtTitleOverlay`，gate 是 `pic 110`）；`dist-cht/` 不放 `.ovl`，
引擎開檔失敗就自動略過。日後若接受更小的字模或改用半形拼寫，補一個檔案即可。

## 十、baked art（credits 職稱）：同樣量測後決定不做

`composer` / `art designer` / `game designer` / `executive producer` 這幾個職稱
完全不在抽字結果裡 → 是畫進美術的 baked art。

量測字高：**約 8 邏輯列**（display 上 20px，÷2.4）。英文點陣字 5–9px 就夠用，
倚天最小字模 16×15 需要 15 列——**塞不下**。硬塞會蓋掉旁邊的東西。

而且 credits 的人名（Mark Seibert、Ken Williams…）本來就是真實姓名保留原文，
職稱一併保留英文反而一致。

## 十一、[HARD] Windows zip 不能放中文檔名

使用者回報「Windows 下載解開後檔案不見了」。根因是 **zip 格式沒有檔名編碼欄位**：

- Info-ZIP 的 `zip` 把檔名以 UTF-8 bytes 寫入，**但不設 UTF-8 旗標**（general purpose bit 11 / EFS）
- 繁中 Windows 的解壓工具看到沒有旗標，就用系統 ANSI（CP950）去解讀那串 UTF-8 bytes
- 輕則檔名亂碼；重則那串 bytes 在 CP950 裡是非法序列，**該檔直接被跳過** → 就是「檔案消失」

修法三層（`tools/mkzip.py` 與兩支 Windows 打包腳本）：

| 層 | 做法 | 為什麼 |
|---|---|---|
| 檔名 | **一律 ASCII**（`PLAY-CAMELOT-CHT.bat`、`README-CHT.txt`） | 根治，中文留在檔案內容裡 |
| zip | 仍設 UTF-8 旗標並在打包後驗一次 | 保險，日後有人加了中文檔名不會回到老問題 |
| 內容 | `.bat` 存 **CP950**、`.txt` 存 **UTF-8 with BOM**，都用 CRLF | cmd 配 `chcp 950` 才顯示得出中文；記事本靠 BOM 辨識 |

**tar.gz 沒有這個問題**（tar 的檔名就是 bytes，macOS 全系統 UTF-8），所以 macOS 包裡的
「啟動.command」「修復-macOS.command」保留中文檔名。

**[雷] 產這種檔案不要「先 cat 再轉檔」**——中間那步靜默失敗時，產物看起來「檔案有在」，
但編碼是錯的（第一次改就是這樣，BOM 沒寫進去卻沒有任何錯誤訊息）。用 python heredoc 一次寫對。

## 十二、待實測

- ~~遊戲內選單列的中文顯示效果~~ → **2026-08-07 實測完畢，三個 bug，見第十二之二節**。
  這一項在待實測欄位裡擺了六天沒做，期間發了兩個版本；玩家一開選單就看到，
  而它就寫在這份文件的「待實測」裡。**待實測清單要在發版前清掉，不是留著。**
- 遊戲物件名（console `vmvars g 1`），供 `send ?<obj> newRoom <n>` 換場用。
- 640×400 upscale 已確認可用（本作無常駐狀態列，KQ1SCI 那個坑不適用）。

## 十二之二、[HARD] 中文為什麼對玩家沒生效（github issue #1，2026-08-07）

回報者附了兩張截圖：選單列的中文糊成一片黑塊、對話框的中文左右互相重疊。
追下去發現的根因比表面嚴重——**patch 版對照著說明操作的玩家，整個遊戲是英文的**。

### 一、`--extrapath` 與 `--language` 在玩家的啟動路徑上都不生效

用 `-d 1` 量出來的（看 `CHT: loaded N translation entries` 這行）：

| 啟動方式 | 中文資料 | 結果 |
|---|---|---|
| `--path=<dir> --auto-detect --language=tw --extrapath=<dir>` | CLI | ✅ 4554 |
| `scummvm camelot --language=tw --extrapath=<dir>` | CLI | ❌ 0 |
| `scummvm camelot`，ini `[camelot] language=zh_TW` | CLI extrapath | ❌ 0 |
| `scummvm camelot`，ini `[scummvm] extrapath=` | ini | ✅ 4554 |
| `scummvm camelot`，ini `[camelot] extrapath=` | ini | ✅ 4554 |
| `scummvm camelot`，資料直接放進遊戲目錄 | game dir | ✅ 4554 |

**只要指定 target，CLI 給的 `--extrapath` 與 `--language` 就會被忽略**，
而「Add Game → 選遊戲 → Start」正是 patch 版說明書要玩家走的流程。
CLAUDE.md ⑥ 寫的「`--extrapath` 指向包內 cht-data 就能啟用中文」只在直接啟動時成立。

**這個 bug 撐過了 v1.0 與 v1.1**，因為我所有的驗證腳本都用
`--path=/game --auto-detect --language=tw`——那是六種組合裡唯一會過的那一種。
**用開發者自己的啟動方式驗收，等於沒驗收。**

### 二、修法：資料在就是中文版，不看語言設定

- 引擎讀 `SCI_CHT_DATA=<dir>`，自己 `SearchMan.addDirectory`（不受啟動路徑差異影響）
- `_chtActive = Common::File::exists("translation.tsv")`，`getLanguage()` 據此回 `ZH_TWN`
- **判定必須放在 `_resMan->init()` 之後**：那才是把遊戲目錄放上搜尋路徑的地方，
  更早探測一律回 false（第一版就是放太早，改完仍然沒生效，白編一次）
- `SCI_CHT_OFF=1` 逃生門，用來跑英文對照組
- 三個 patch 啟動器（AppImage / .bat / macOS .command）都要 export `SCI_CHT_DATA`

### 三、低解析（選單）路徑的三個疊在一起的顯示 bug

同一則 issue 的第二個症狀。低解析路徑只走選單與缺字 fallback，先前從未實機看過
（第十二節「待實測」擺著沒做）：

| 問題 | 症狀 | 修法 |
|---|---|---|
| 黑字被膨脹 | 選單列整排糊成黑塊 | 低解析**不做**膨脹——膨脹是給 hi-res 外框字用的，選單是單純黑字白底、沒有第二趟 |
| advance 14px < 字模 16px | 同一行越後面的字疊得越厲害 | `kBig5Width` 14 → 16（倚天字模本來就是 16 寬） |
| 用行距當字模高度 | 字底部被切掉 2 列 | 分開 `_big5Height`（行距，會 cap）與 `_big5GlyphH`（字模真高） |

**第三點是第八之二節那個 bug 的同一個病**：行距與字模高度是兩件事，混用就出錯。
hi-res 修的時候沒想到低解析也有一份。

## 十三、推廣片（2026-08-01）

配樂用**原版 MT-32 側錄**（rulebook 93 鐵則 1：素材真實性，不可自產合成）。

**側錄方式**（`tools/record_mt32.sh`）：`SDL_AUDIODRIVER=disk` + `SDL_DISKAUDIOFILE`，
引擎帶 `--music-driver=mt32 --extrapath=<放 ROM 的目錄>`。

- **[HARD] 不要設 `SDL_DISKAUDIODELAY=0`**。SCI 的音樂排序器依**遊戲時鐘**推進；
  設成全速輸出會灌出 GB 級檔案，而且因為排序器沒跟著跑，內容整段是靜音。必須即時側錄。
  實測 146 秒 wall-clock 得到 25.7 MB raw（44100/stereo/s16le），時長剛好對得上。
- **標題曲在 3–65 秒**，65 秒後遊戲不再播音樂。逐 5 秒 `volumedetect` 掃出來的，
  不要假設「音樂在最前面」。抽 3.5–64.5 秒當配樂，mean −29.6 dB、max −12.1 dB（無 clipping）；
  合成時 `volume=8dB` 提上來。

**Headless 操作的兩個雷**：

- **Xvfb 沒有 window manager** → `xdotool windowactivate` 會失敗
  （`Your windowmanager claims not to support _NET_ACTIVE_WINDOW`）。
  PointerRoot focus 模式下，**把滑鼠 `mousemove` 進視窗**就能讓 XTEST 鍵盤事件送達。
- **開場選單只吃鍵盤，不吃 `xdotool click`**。游標移到按鈕上、click 送出去，按鈕不會有反應。
  正確做法是 `Return`：第一次叫出選單，第二次選中預設的「觀看片頭」。
  `tools/capture_ingame.sh` 裡的 `click 455 415` 是更早期版本的座標，現在點空——
  它當年之所以能進遊戲，其實是靠後面那幾個 `Escape` 與 `Return`。

**影片合成**（`tools/make_promo.sh`）：靜態圖 + fade，不用 zoompan（幀數爆炸）；
配樂先 `aloop` 再 `atrim` 到影片長度，不要 `-shortest`（會以較短的音軌為準截掉結尾卡）。
theme 色票取自實機截圖的 histogram：羊皮 `#FDF1CC`、封蠟紅 `#B2493C`、深棕 `#5A2F1D`，
母題沿用遊戲畫面本身的四角紋章方塊。

- **[雷] ImageMagick 的 `-annotate` geometry 只吃 `+X+Y`**。寫成 `+5+5-120` 想表達
  「X=5, Y=5-120」會被解析成 (5,5)，標題與副標就疊在一起。要自己算好寫 `+5-115`。
- **[雷] 產出的 mp4 要抽幀逐張看**。這次靠讀圖才發現有一格用到了「被 debugger console
  蓋住半個畫面」的廢截圖——檔案存在、尺寸正常，只看檔名完全看不出來。

**[IP] 影片配樂是原版遊戲音樂**（作曲 Mark Seibert），著作權不屬於本專案。
產物只放本機 `promo/`（已 gitignore），要公開上傳前需先確認授權（rulebook 93 但書）。
