# FisherGO 2.0 — 完整規劃文件

> **實作指引：** 使用 subagent-driven-development skill 逐任務執行，每個任務後進行規格審核與代碼品質審核。

**目標：** 將 FisherGO 從「帶地圖的釣魚記錄工具」全面升級為「Pokémon GO 風格的真實世界釣魚遊戲」—— 以地圖為首頁、以遊戲化機制驅動留存、以圖檔化小遊戲提升體驗。

**核心方向：**
1. 主頁 = 地圖遊戲場景（不再只是地圖工具）
2. 其他頁面 = 地圖 HUD 按鈕（非傳統 tab bar）
3. 釣魚小遊戲 = 圖檔背景 + CustomPainter 互動層混合架構
4. 遊戲化系統：體力、經驗值、稀有度、天氣、社群

---

## 📌 第一階段：核心重構（地圖首頁 + HUD 系統）

### Task 1: 分析並拆解 CatchLogScreen（技術債）

**目標：** 將 2382 行的 `catch_log_screen.dart` 拆解為職責單一的子 widget，避免日後改動時雪崩式影響。

**檔案：**
- 修改：`lib/features/catches/presentation/catch_log_screen.dart`

**現況分析（不寫測試，只做理解）：**

用 `read_file` 依序讀取：
```
offset=80   → _mapDetailTier 渲染邏輯
offset=300  → _buildGameHUD（遊戲 HUD 按鈕組）
offset=600  → _buildAddCatchSheet（新增記錄 sheet）
offset=900  → _buildFishingMinigame（釣魚小遊戲入口）
offset=1200 → _SpotCommunityService 定義
offset=1600 → _buildCatchDetailSheet（詳情頁）
offset=2000 → 存檔 / Sync / 匯出邏輯
```

**拆解方向（不做程式碼，只規劃）：**

| 子 widget | 職責 |
|---|---|
| `_GameMapLayer` | 地圖本體 + marker 渲染 + 玩家位置 |
| `_GameHUD` | 右下角浮動功能按鈕組 |
| `_FishingSpotMarker` | 單一釣點 marker widget |
| `_PlayerAvatarMarker` | 玩家位置 avatar |
| `_AddCatchSheet` | 新增記錄 bottom sheet |
| `_MinigameOverlay` | 釣魚小遊戲 overlay |
| `_CatchDetailSheet` | 捕捉詳情 bottom sheet |
| `_WeatherWidget` | 天氣影響顯示 |
| `_DailyMissionWidget` | 每日任務 HUD badge |

**驗證：** `flutter analyze` 零 error 即完成。

---

### Task 2: 建立新 `GameHomeScreen`（地圖首頁）

**目標：** 新建 `lib/features/game_home/presentation/game_home_screen.dart`，做為首頁。將 `CatchLogScreen` 內的 `gameHome: true` 行為遷移至此專用 widget。

**檔案：**
- 建立：`lib/features/game_home/presentation/game_home_screen.dart`
- 建立：`lib/features/game_home/widgets/` 目錄（子 widget）
- 修改：`lib/core/widgets/app_shell.dart` — 將 index 0 改為 `GameHomeScreen`

**`GameHomeScreen` 佈局架構：**

```
Stack
├── FlutterMap（底層，真實地理地圖）
│   ├── TileLayer（淺色地圖底圖）
│   └── MarkerLayer
│       ├── [釣點 markers] — 按 zoom 層級渲染
│       └── [玩家 avatar marker] — 固定在螢幕中心
├── _GameMapOverlay（半透明遊戲風格疊加層）
│   ├── 頂部：玩家狀態列（等級、金幣、體力 bar）
│   └── 左上：天氣圖示 + 今日任務 badge
├── _SpotInfoCard（點擊釣點後的資訊卡）
└── _FloatingActionCluster（右下方功能按鈕組）
```

**玩家狀態列佈局（左上 → 右上膠囊）：**

```
[LV.5 🐟] [🪙 12,500] [❤️❤️❤️❤️♡ Energy: 4/5]
```

**浮動按鈕組（右下方圓形叢集）：**

```
需求：5 個主要功能按鈕
1. 圖鑑 (Fish Encyclopedia)
2. 背包 (Inventory/Bait)
3. 商店 (Shop)
4. 角色 (Character Profile)
5. 比賽 (Tournaments/Rankings)
```

**按鈕樣式（參考 Pokémon GO HUD）：**
- 圓形半透明背景（80×80px）
- 白色 icon + 底部 label
- 點擊後進入對應頁面（不改變地圖 view，推薦用 bottom sheet 或 overlay panel）

**驗證：**
```bash
cd /c/Users/s0829/fishergo
flutter analyze
# 預期：No issues found
```

---

### Task 3: 重構 AppShell 導航架構

**目標：** AppShell 從 IndexedStack tab 切換改為「地圖始終在底層、功能頁面以 overlay / bottom sheet 呈現」的架構。

**當前架構（index 切換）：**
```dart
IndexedStack(index: _index, children: [Map, 圖鑑, 記錄, 排行榜, 設定])
```

**目標架構（地圖 + overlay）：**

```dart
Scaffold(
  body: Stack(
    children: [
      GameHomeScreen(mapOnly: true),      // 地圖永遠在底
      if (_activeSheet != null) _buildSheet(_activeSheet),  // 功能頁 overlay
    ],
  ),
  // 浮動按鈕由 GameHomeScreen 內部管理
)
```

**好處：**
- 地圖不因切換頁面而 re-build
- 地圖上的 markers / 玩家位置保持不變
- 玩家可以在查看圖鑑時隨時觀看地圖

**AppShell 簡化後：**

```dart
class AppShell extends StatefulWidget {
  // _activeSheet: 'encyclopedia' | 'inventory' | 'shop' | 'profile' | 'tournament' | 'settings' | null
  // _buildSheet(type) 回傳對應 widget（BottomSheet 或全屏 overlay）
}
```

**驗證：** 舊功能（圖鑑、記錄、排行榜、設定）以 overlay 方式正常開啟，`flutter analyze` 通過。

---

## 📌 第二階段：圖檔化釣魚小遊戲

### Task 4: 生成釣魚小遊戲圖檔 Asset

**目標：** 生成 3 張遊戲場景圖（用 image_generate skill），做為小遊戲的背景圖。

**需要生成的圖：**

| 圖檔 | 用途 | 風格 |
|---|---|---|
| `fishing_scene_harbor.png` | 香港碼頭場景背景 | 手繪/卡通風，半透明疊加在地圖上 |
| `fishing_minigame_ui.png` | 浮標 + 水面互動區背景 | 俯視圖/近景，水面波紋 |
| `fishing_result_success.png` | 成功釣上魚結果畫面 | 角色 cut-in + 魚 sprite + 金幣動畫 |

**生成 prompt 風格指引：**

```
fishing_scene_harbor:
"Pixel art style Hong Kong harbor fishing scene, gentle water waves, wooden pier dock, 
fishing rods silhouetted, soft watercolor texture, game UI overlay friendly, transparent edges, 
no text, 16:9 aspect ratio"

fishing_minigame_ui:
"Simple 2D top-down fishing game UI mockup, bobber floating on gentle waves, 
circular timing indicator ring at bottom, fish shadow silhouettes visible in water, 
semi-transparent so map shows through, no text, game art style"

fishing_result_success:
"Cartoon illustration of fisherman proudly holding up a shiny fish, coins flying around, 
celebration sparkles, confident smile, HK harbor background silhouette, 
victory screen style, no text, transparent background"
```

**圖檔儲存位置：**
```
assets/images/game/
├── fishing_scene_harbor.png
├── fishing_minigame_ui.png
└── fishing_result_success.png
```

**驗證：** `ls assets/images/game/` 確認 3 張圖存在。

---

### Task 5: 建構 `FishingMinigameWidget`（混合架構）

**目標：** 建立 `lib/features/game_home/widgets/fishing_minigame_widget.dart`，實現：
- 圖檔做背景（Container + Image）
- CustomPainter 畫互動層（成功區、魚影、浮標位置）
- 計時器 + 判定邏輯

**架構分層：**

```
FishingMinigameWidget（StatefulWidget）
├── Stack
│   ├── Layer 1: Container + Image (fishing_scene_harbor.png) — 場景背景
│   ├── Layer 2: CustomPainter — 浮標位置、浪費區域
│   ├── Layer 3: CustomPainter — 魚影移動（每 2s 換位置）
│   ├── Layer 4: _TimingBarWidget — 成功區 + 滑動指示器
│   └── Layer 5: AnimatedOverlay — 成功/失敗動畫
└── _MinigameController（管理狀態：waiting, casting, bite, reeling, result）
```

**CustomPainter 實作重點：**

```dart
class _BobberPainter extends CustomPainter {
  // 畫浮標：兩個圓圈 + 魚線 + 水面波紋
  // 根據 minigameState 調整動畫（idle / bite / reel）
}

class _FishShadowPainter extends CustomPainter {
  // 畫魚影：4-5 個半透明橢圓，在水面隨機移動
  // 稀有魚影更深色、更大
}

class _TimingBarPainter extends CustomPainter {
  // 畫底部 timing bar：
  // - 成功區（綠色扇形，寬度由魚竿裝備決定）
  // - 滑動指示器（紅色標記，來回移動）
  // - 魚竿越好 → 成功區越大
}
```

**狀態機：**

```
idle → (玩家點擊) → casting → (浮標落水動畫 0.5s) → waiting
waiting → (魚咬鉤觸發：隨機 2-8s) → bite → (魚影出現)
bite → (玩家點擊拉竿) → reeling → (Timing 判定)
reeling → (成功) → result_success
reeling → (失敗) → result_fail → idle
```

**判定邏輯：**

```dart
bool _evaluateCatch(TimingResult timing) {
  final equipment = _equippedItems['rod'];
  final baseSuccessRate = _getBaseSuccessRate(fishRarity);
  final rodBonus = _getRodBonus(equipment); // 魚竿越好成功區越大
  final timingBonus = _getTimingBonus(timing.offset); // timing 越準加成越高
  
  final totalChance = (baseSuccessRate + rodBonus + timingBonus).clamp(0.0, 0.95);
  return math.Random().nextDouble() < totalChance;
}
```

**驗證：** `flutter test` 通過，minigame 可以完成一次完整流程（casting → bite → reeling → result）。

---

### Task 6: 實裝裝備系統對小遊戲的影響

**目標：** 讓魚竿、背包裡的道具實際影響小遊戲參數。

**影響機制：**

| 裝備 | 屬性 | 效果 |
|---|---|---|
| 魚竿（Rod） | `timingZoneBonus` | 成功區寬度 +10%~+30% |
| 魚餌（Bait） | `rarityBoost` | 稀有魚出現機率 +5%~+20% |
| 背包（Lure） | `biteSpeedBonus` | 魚咬鉤速度加快/減慢 |
| 頭盔/衣服 | `xpBonus` | 成功後經驗值 +10%~+25% |
| 鞋子 | `energyCostReduction` | 體力消耗 -1 點 |

**需要新增的資料檔案：**
```
lib/features/profile/data/equipment_definitions.dart
lib/features/profile/domain/equipment.dart
lib/features/profile/data/equipment_effects.dart
```

**驗證：** 佩戴不同魚竿時，小遊戲成功區視覺大小不同。

---

## 📌 第三階段：遊戲化核心系統

### Task 7: 體力系統 + 每日重置

**目標：** 加入 Energy 消耗機制，驅動每日回訪。

**規則：**
- 玩家初始體力：5/5
- 每嘗試一次釣魚（不論成功與否）：-1 體力
- 體力歸零：无法进行新钓鱼，需等待自然回复或使用道具恢复
- 自然回覆：每小時 +1 體力（App 打開時計算，離開期間不計）
- 道具恢復：商城購買「能量飲料」立即 +3 體力

**資料模型：**

```dart
class PlayerGameState {
  int energy;        // 當前體力
  int maxEnergy;      // 上限（可升級）
  DateTime lastEnergyReset;  // 上次體力回覆時間
  int totalXp;
  int level;
}
```

**UI 呈現：**
- 左上角能量條：`❤️×5` 或漸層進度條
- 體力低於 2 格：能量條變紅色 + pulse 動畫
- 體力為 0：點擊「開始釣魚」按鈕 → 彈出「體力不足」提示 + 商城連結

**驗證：** `flutter test` 體力扣減邏輯正確，隔日重置正常。

---

### Task 8: 經驗值與等級系統

**目標：** 每次成功釣魚獲得 XP，升級後解鎖功能、獲得獎勵。

**規則：**
- 每次成功：基礎 XP = 魚類稀有度星級 × 10
- 魚竿/衣服加成：額外 +XP
- 等級計算：`level = (XP / 100).floor()`（每級需 100 XP）
- 等級 1 = 0 XP，等級 2 = 100 XP，等級 5 = 400 XP
- 每升級：解鎖新魚種 + 送商城金幣

**等級里程碑獎勵：**

| 等級 | 解鎖 |
|---|---|
| 2 | 解鎖「烏頭魚」魚種 |
| 3 | 解鎖「石斑」魚種 |
| 5 | 解鎖「龍蝦」魚種 |
| 10 | 解鎖「比賽」功能 |
| 15 | 解鎖「公會」功能 |

**驗證：** 成功釣魚後 XP 增加，達到門檻後等級提升、UI 更新。

---

### Task 9: 天氣系統

**目標：** 天氣影響魚類出現機率與 XP 加成（接駁真實香港天氣）。

**天氣類型：**

| 天氣 | 出現機率加成 | XP 加成 | 特效 |
|---|---|---|---|
| ☀️ 晴 | 一般魚 +20% | +0% | 晴朗背景 overlay |
| 🌧️ 雨 | 所有魚 +30% | +10% | 雨滴粒子效果 |
| ☁️ 多雲 | 一般魚 +10% | +5% | 雲層 overlay |
| 🌊 颱風/大風 | 稀有魚 +50% | +30% | 風吹動畫（危險但高回報） |

**天氣資料來源：**
- 使用 Open-Meteo free API（不需 key）：`https://api.open-meteo.com/v1/forecast?latitude=22.3193&longitude=114.1694&current_weather=true`
- 每天早上 6:00 cron 更新一次天氣狀態（寫入 local storage）
- 或在 App 打開時即時讀取

**驗證：** 天氣讀取成功並正確顯示，魚類出現機率隨天氣調整。

---

### Task 10: 稀有度與魚種分佈

**目標：** 魚類稀有度影響出現機率與捕捉難度。

**稀有度分級：**

| 星級 | 名稱 | 出現率 | 基礎 XP | 捕捉難度 |
|---|---|---|---|---|
| ⭐ | 常見 | 50% | 10 | 易（成功區大） |
| ⭐⭐ | 不常見 | 30% | 20 | 中 |
| ⭐⭐⭐ | 稀有 | 15% | 40 | 較難 |
| ⭐⭐⭐⭐ | 非常稀有 | 4% | 80 | 難 |
| ⭐⭐⭐⭐⭐ | 傳說 | 1% | 150 | 極難（成功區極小） |

**魚影視覺化區分：**
- 常見：淺灰色小魚影，快速游過
- 稀有：金色大魚影，慢速且路徑穩定
- 傳說：彩虹光暈 + 大魚影，非常緩慢

**魚種加成：**
- 特定魚種在特定地點/天氣出現率更高（`fish_species.dart` 已有 `habitat` 欄位）
- 新增 `preferredWeather` 欄位

**驗證：** 魚影大小/顏色與稀有度對應，成功率隨稀有度調整。

---

## 📌 第四階段：社群與留存

### Task 11: 每日任務系統

**目標：** 每日 3 個隨機任務，完成後獲得金幣/XP/道具獎勵。

**任務類型：**

| 任務 | 內容 | 獎勵 |
|---|---|---|
| 🐟 今日第一桿 | 成功釣到一條魚 | 🪙 100 金幣 |
| 📸 攝影師 | 上傳一張實拍照片 | 🪙 50 + 魚餌 × 1 |
| 🏆 收集三種 | 今日累計捕捉 3 種不同魚類 | 🪙 200 + XP × 50 |
| ⭐ 稀有獵人 | 今日捕捉至少 1 條 ⭐⭐⭐ 魚 | 🪙 500 |
| 🎯 精准一桿 | 今日 timing 判定 Excellent | XP × 30 |

**每日重置：** 香港時間 00:00 自動重置任務進度。

**UI 呈現：**
- 左上角天氣 badge 旁：`📋 2/3`（顯示今日完成進度）
- 點擊開啟每日任務面板（bottom sheet）

**驗證：** 任務追蹤正確，跨日重置正常，獎勵發放正確。

---

### Task 12: 比賽系統（基礎版）

**目標：** 玩家之間的每周比賽，促進競爭與留存。

**比賽規則：**
- 比賽類型：
  - 「最多捕捉」：一周內捕捉最多魚類（按數量計）
  - 「稀有獵人」：一周內捕捉最高稀有度魚種
  - 「攝影師」：一周內上傳最多實拍照片
- 報名費：100 金幣
- 獎勵：
  - 第 1 名：🪙 1000 + 獨家稱號
  - 第 2-3 名：🪙 500
  - 參與獎：🪙 100（只要有捕捉即獲得）

**UI 入口：** 地圖右下角按鈕叢集中的「第 5 按鈕：比賽」

**驗證：** 比賽排行榜正確排序，獎勵正確發放。

---

### Task 13: 照片驗證流程優化

**目標：** 將「拍照上傳」從附加功能提升為核心遊戲循環。

**新流程（參考 Pokémon GO 精靈捕捉）：**

```
步驟 1：選擇魚種（從出現的候選中選）
步驟 2：開啟相機，拍攝真實魚類照片
步驟 3：AI 視覺化比對（簡單版：用魚類名稱/外觀關鍵字比對）
步驟 4：確認後完成捕捉
```

**實拍獎勵加成：**
- 有實拍：XP × 1.5，額外金幣 +20
- 無實拍：正常 XP

**相機功能：** 使用 `image_picker` 套件（已存在），疊加：
- 魚類比例參考線（幫助用戶拍出清楚角度）
- 計時器（5 秒倒數）

**驗證：** 拍照成功，相片附加到 CatchLogEntry，本地儲存正確。

---

## 📌 第五階段：技術架構升級

### Task 14: 替換 `dart:html` 為 `package:web`

**現況：** `lib/core/web_session_stub.dart` 和 `web_session_web_impl.dart` 使用 `dart:html`（即將棄用）。

**目標：** 遷移到 `package:web`（Chrome DevTools Protocol 官方綁定）。

**步驟：**
1. `flutter pub add web`
2. 搜尋所有 `import 'dart:html'`
3. 替換為 `import 'package:web/web.dart'`
4. 調整 API（例如 `querySelector` → `document.querySelector`）

**驗證：** `flutter build web` 成功，web 功能正常。

---

### Task 15: Hive 資料遷移至 SQLite

**現況：** 使用 Hive 做本地儲存（`CatchLogLocalDataSource`）。

**目標：** 評估遷移到 `drift`（SQLite）或保留 Hive（穩定可繼續用）。

**建議：** 先不做遷移（YAGNI）。Hive 已穩定，未來若有離線同步需求再遷移。

**改進方向（不換技術棧）：**
- 建立 `PlayerGameStateBox` 儲存玩家遊戲狀態（Energy、XP、等級）
- 建立 `DailyMissionBox` 儲存每日任務進度
- 現有 `CatchLogBox` 繼續使用

**驗證：** 新舊資料 box 正常讀寫。

---

### Task 16: Flutter Web 部署優化

**目標：** 減少 web build 大小與載入時間。

**優化方向：**
- 圖片 asset 壓縮（PNG → WebP）
- 地圖 tiles 使用輕量底圖（OpenStreetMap 預設已較輕）
- 程式碼分割（lazy load 非首屏代碼）
- Vercel Edge Caching 開啟

**驗證：** Lighthouse Performance Score > 80。

---

## 📌 第六階段：界面與美術

### Task 17: 遊戲風格 UI 主題

**目標：** 將全 App 主題色從「通用 Material」改為「海洋/碼頭遊戲風」。

**色彩方案：**

| 用途 | 顏色 |
|---|---|
| 主色（Primary） | `#1E88E5`（海洋藍） |
| 次色（Secondary） | `#43A047`（魚群綠） |
| 強調色（Accent） | `#FFB300`（金幣黃） |
| 危險色 | `#E53935`（警告/體力低） |
| 背景 | `#E3F2FD`（淡藍海水） |
| 深色背景 | `#0D47A1`（深海藍） |
| 文字 | `#212121`（深灰）/ `#FFFFFF`（白） |

**字體：** 使用 `Google Fonts: Nunito` 或 `Noto Sans HK`（繁體中文友好）

**驗證：** 全 App 配色統一，無突兀的預設 Material 顏色。

---

### Task 18: 音效與震動回饋

**目標：** 加入基本遊戲音效（可選，用戶可靜音）。

**音效清單：**
- 拋竿：`cast.wav`
- 浮標落水：`splash.wav`
- 魚咬鉤：`bite.wav`
- 拉竿成功：`success.wav`
- 拉竿失敗：`fail.wav`
- 升級：`level_up.wav`
- 金幣獲得：`coin.wav`

**實作方式：**
- 存放位置：`assets/audio/`
- 播放工具：`audioplayers` package
- 使用者偏好：首次使用時詢問是否開啟音效，存入 preferences

**驗證：** 音效正確觸發，靜音模式正常。

---

## 📌 執行順序（Priority）

```
Phase 1（核心重構）        →  Task 1, 2, 3      [技術債 + 地圖首頁]
Phase 2a（視覺提升）       →  Task 4, 5          [圖檔 + 小遊戲]
Phase 2b（裝備影響）       →  Task 6             [裝備系統]
Phase 3（遊戲化）          →  Task 7, 8, 9, 10   [體力 + 等級 + 天氣 + 稀有度]
Phase 4（留存功能）         →  Task 11, 12, 13    [每日任務 + 比賽 + 拍照]
Phase 5（技術架構）         →  Task 14, 15, 16    [web遷移 + 資料 + 部署]
Phase 6（界面美術）         →  Task 17, 18        [UI主題 + 音效]
```

**預計總工作量：** 18 個任務  
**優先執行 Phase 1（核心重構）** — 其他 Phase 可獨立並行

---

## ⚠️ 風險與 Trade-off

| 風險 | 緩解方案 |
|---|---|
| 圖檔增加 web build 大小 | 使用 WebP、lazy load、僅首屏 asset 打包 |
| 小遊戲 CustomPainter 複雜度 | 先做基礎版（靜態 timing bar），後續加動畫 |
| 天氣 API 延遲 | 快取 1 小時，失敗時用上次快取值 |
| 體力系統影響用戶體驗 | 設計「體力不足」為正向鉤子（引導商城消費） |
| 比賽系統後端需求 | 先做「本地排名」展示，未來再接 Supabase 多人 |

---

## ✅ 驗收標準（每個 Phase 完成後）

| Phase | 驗收條件 |
|---|---|
| Phase 1 | `flutter analyze` 零 error，App 可正常瀏覽地圖 + 開啟所有功能頁 |
| Phase 2a | 釣魚小遊戲可完整執行一次（從點擊到結果） |
| Phase 2b | 更換魚竿後，成功區大小視覺可見變化 |
| Phase 3 | 體力扣減/回覆正常，XP 等級計算正確，天氣顯示準確 |
| Phase 4 | 每日任務追蹤正確，比賽排行榜正常，拍照成功附加 |
| Phase 5 | web build < 5MB，Lighthouse Performance > 70 |
| Phase 6 | 全 App 配色統一，音效正確觸發 |