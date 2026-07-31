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

- **[雷] 這個選單 Escape 與 Tab 都無效**，只吃滑鼠點擊。headless 擷取要用
  `xdotool mousemove <x> <y>` + `click 1`，座標見 `tools/capture_ingame.sh`。
- credits 會循環輪播（attract mode），不點選單就一直跑。

## 五、漏抽字串（要補，隨查隨記）

| 字串 | 出現位置 | 狀態 |
|---|---|---|
| `Camelot Game Options:` | 開場選單標題 | **未抽到**，需另找來源 |

`See the Intro` / `Start New Game` / `Restore Game` 三顆按鈕**已在 skeleton 內**。

## 六、術語（glossary）

譯名表在 `translation/names.tsv`（英文＜TAB＞中文＜TAB＞依據）。三條硬規則：

1. **1990 年台灣雜誌的譯名優先**（甘美特、蘭斯洛特、葛拉漢、黑武士…），實物佐證在 `../banner/`。
2. 宗教與神話專名查**通行中譯**，不自創音譯。
3. 待定項在定案前不得進入翻譯批次。

**遊戲用的是古拼法**，抽字與譯名對照時別按現代拼法找：

| 遊戲內拼法 | 現代拼法 | 中文 |
|---|---|---|
| `Gawaine` | Gawain | 高文 |
| `Launcelot` | Lancelot | 蘭斯洛特 |
| `Gwenhyver` | Guinevere | 待定 |
| `Excaliber` | Excalibur | 待定 |

## 七、中文顯示（2026-08-01 實機驗證通過）

啟用方式：**`--language=tw`**（SCI0 走 CLI 即可，不必寫進 target config——
那是 SCI1 的作法，別混）。實機確認對白框中文正確斷行、標點正常、框會依中文長度自動加大。

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

## 八、待實測

- 遊戲內選單列（File／Game／Speed／Action／Information）的中文顯示效果，
  尤其**選單列高度**（LSL2 踩過：9px 選單列裝不下 14px 中文 → 殘影）。
  低解析路徑的 advance 目前沿用 kq4 的 `kBig5Width=14`，而倚天 16×15 glyph 寬 16，
  可能被裁掉右邊 2px（kb 建議選單用 16）——要實機看過再調。
- 遊戲物件名（console `vmvars g 1`），供 `send ?<obj> newRoom <n>` 換場用。
- 640×400 upscale 已確認可用（本作無常駐狀態列，KQ1SCI 那個坑不適用）。
