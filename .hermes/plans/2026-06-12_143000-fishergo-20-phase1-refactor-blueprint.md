# Task 1 分析報告：CatchLogScreen 重構藍圖

> **目標：** 將 2382 行單一檔案拆解為職責單一的子 widget
> **分析方法：** 逐段閱讀 `catch_log_screen.dart`，識別所有 widget、狀態與方法

---

## 📊 現況地圖（2382 行）

### 狀態欄（State）
| 狀態 | 行 | 用途 |
|---|---|---|
| `_mapZoom` | 80 | 地圖縮放層級 |
| `_mapDetailTier` | 81 | 渲染詳細度（0/1/2） |
| `_latitude / _longitude` | 69-70 | 玩家 GPS 位置 |
| `_checkpoints` | 71 | 軌跡點列表 |
| `_consumables` | 74 | 魚餌背包數量 |
| `_equippedItems` | 75 | 當前裝備 |
| `_pending` | 64 | 待同步魚獲佇列 |
| `_selectedSpeciesId` | 66 | 新增記錄的魚種 |
| `_photoPath` | 68 | 拍照路徑 |
| `_autoCheckpointEnabled` | 77 | 自動打卡開關 |
| `_loadingOtherSpecies` | 79 | 載入遠端魚種 |

### 主要方法
| 方法 | 行 | 職責 |
|---|---|---|
| `initState` | 84-109 | 初始化所有 service |
| `build` | 158-189 | 根據 `gameHome` 分叉 |
| `_buildCheckpointSection` | 352-598 | 地圖 + marker + 控制項 |
| `_buildGameHomeRadar` | 601-759 | 全屏地圖遊戲首頁 |
| `_buildGameHudButtons` | 784-814 | 底部 HUD 按鈕列 |
| `_buildForm` | 213-319 | 新增魚獲表單 |
| `_buildPendingList` | 322-349 | 待同步列表 |
| `_showSpotBottomSheet` | 1095-1161 | 單一釣點詳情 |
| `_showClusterBottomSheet` | 1035-1078 | 叢集釣點列表 |
| `_virtualFishAtSpot` | 1163-1241 | 虛擬釣魚流程 |
| `_save` | 1319-1371 | 新增魚獲到佇列 |
| `_syncPending` | 1280-1317 | 同步到 Supabase |
| `_startLocationTracking` | 817-843 | GPS 追蹤 |
| `_autoCheckpointByGeofence` | 938-966 | 範圍自動打卡 |
| `_handleMapPositionChanged` | 991-1001 | 地圖移動處理 |
| `_renderSpotsByDetailTier` | 1003-1033 | 按 zoom 渲染 marker |
| `_rollFishForSpot` | 1256-1278 | 魚種隨機抽取 |

---

## 🔧 拆解方案

### 架構改變

```
lib/features/catches/presentation/catch_log_screen.dart（2382行）
                          ↓ 拆解
lib/features/game_home/
├── presentation/
│   └── game_home_screen.dart     ← 新首頁（整合現有 gameHome:true 邏輯）
└── widgets/
    ├── game_map_view.dart        ← 地圖本體 + marker 渲染（_buildCheckpointSection）
    ├── game_hud_layer.dart       ← 所有 HUD widget
    ├── player_avatar_marker.dart ← _PlayerAvatarMapMarker
    ├── fishing_spot_marker.dart   ← _FishingSpotMapMarker
    ├── spot_info_sheet.dart      ← _showSpotBottomSheet（獨立的 bottom sheet）
    ├── cluster_sheet.dart        ← _showClusterBottomSheet
    └── minigame_dialog.dart      ← _FishingMinigameDialog + 兩個 CustomPainter

lib/features/catches/presentation/
├── catch_log_screen.dart         ← 精簡版（移除 gameHome 邏輯）
└── add_catch_sheet.dart         ← 新增魚獲表單（_buildForm + _save）

lib/features/catches/data/
└── fishing_spot_models.dart      ← _FishingSpot, _RenderedSpot
```

### 詳細拆分清單

#### 新建 Widget（從 bottom 抽出的遊戲 HUD）

| widget | 從哪裡來 | 職責 |
|---|---|---|
| `_RadarGridPainter` | ~line 500 區域 | 雷達網格 CustomPainter（留在原地） |
| `_MapHudPill` | ~line 532 區域 | 地圖 HUD 狀態膠囊 |
| `_GameTopStatusBar` | 1883+ | 頂部狀態列（已存在，搬至 game_hud_layer.dart） |
| `_GameSideHudButton` | ~line 712 區域 | 右側垂直按鈕（已存在） |
| `_GameBottomCommandBar` | ~line 749 區域 | 底部指令列（已存在） |
| `_GameHudButton` | ~line 788 區域 | 底部橫排 HUD 按鈕 |

> 💡 **現況發現：** 多個 `_GameSideHudButton` 在 `_buildGameHomeRadar` 內直接用 `widget.onOpenScreen?.call(n)` — 這是硬編碼 index！
> 未來改用 enum：`GameScreen.encyclopedia` 而非 `1`，`GameScreen.profile` 而非 `4`。
> 這也讓 AppShell 重構（Task 3）更乾淨。

#### 新建 Data 模型

| model | 來源 | 用途 |
|---|---|---|
| `_FishingSpot` | 行 1500+ 區域（隱藏類） | 釣點資料模型 |
| `_RenderedSpot` | 行 1500+ 區域 | 叢集渲染模型 |
| `_SpotCommunityService` | 行 1200 區域 | Supabase 遠端查詢 |

#### 精簡後 CatchLogScreen

移除以下邏輯後，預計從 2382 行減至 ~400 行：

1. `gameHome: true` 的完整分支邏輯（搬至 `GameHomeScreen`）
2. `_buildGameHomeRadar`（整個方法 158 行）
3. `_buildGameHudButtons`（31 行）
4. `_RadarGridPainter`（約 40 行）
5. `_MapHudPill`（約 20 行）
6. 遊戲 HUD 按鈕 widget（5 個 `_GameHudButton` 等，約 200 行）
7. `_PlayerAvatarMapMarker`（50 行）
8. `_FishingSpotMapMarker`（60 行）
9. `_SpotCommunityService`（約 80 行）
10. `_FishingEquipmentBonus`（49 行）
11. `_FishingMinigameDialog` 整個對話框（156 行）
12. 兩個 CustomPainter（`_FishingScenePainter` + `_FishingTimingPainter`，約 150 行）

---

## ⚠️ 技術債警告

### 1. 硬編碼 Screen Index
```dart
// 壞：硬編碼
widget.onOpenScreen?.call(4)  // 到底是「商店」還是「角色」？

// 好：enum
enum GameScreen { map, encyclopedia, catchLog, leaderboard, shop, profile }
onOpenScreen?.call(GameScreen.profile.index)
```

### 2. 雙層地圖邏輯重複
`_buildCheckpointSection` 和 `_buildGameHomeRadar` 都有幾乎相同的 FlutterMap 建構，只是 overlay 透明度不同。應該合併成一個參數化方法或共用 widget。

### 3. `_SpotCommunityService` 在 State 內部
應該提升至獨立的 service class 並通過 constructor 注入，否則無法單獨測試。

### 4. 缺少 `didChangeDependencies` 重新整理
`ProfileWalletService` 的資料（`_loadConsumables`、`_loadEquippedItems`）只在 `initState` 呼叫一次。用戶在商城購買道具後回來，庫存不會更新。建議在 `didChangeDependencies` 中重新整理。

---

## 📋 Task 1 產出清單

完成 Task 1 後，應產生：

1. **本檔案**（`catch_log_screen_refactor_blueprint.md`）— 分析結果
2. **`lib/features/game_home/`** 目錄 — 新首頁起點
3. **`lib/features/catches/widgets/`** 目錄 — 拆出的 widget
4. **更新的 `catch_log_screen.dart`** — 精簡版
5. **新的 `GameScreen` enum** — 取代硬編碼 index
6. **`flutter analyze` 零 error** — 完成驗證

---

## 與 Task 2、Task 3 的銜接

- **Task 2** 會建立 `GameHomeScreen`，並從 `catch_log_screen.dart` 中取出 `gameHome: true` 的邏輯重構放入。
- **Task 3** 會使用 Task 2 建立的 `GameScreen` enum 重構 `AppShell`。
- **Task 1 的技術債警告**（硬編碼 index、雙層地圖重複）在 Task 2/3 實作時一并修正。

**建議實作順序：** Task 1 → Task 2 → Task 3（現在的 Phase 1 順序），但實際上 Task 2 的輸出（`GameHomeScreen` + `GameScreen` enum）會成為 Task 3 的輸入。