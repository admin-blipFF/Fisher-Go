# FisherGO 功能實作計劃

## 目標
1. 公告頁 + 每日首次登入紅點提示
2. 船家服務（商店內購入，指定水域 5 個免 GPS 釣點）
3. 船家對白系統
4. 首次開啟教學模式（強制 #010 魚，弹出「又係依D!」）

---

## 功能 1：教學系統

### 現況
- 無 tutorial 狀態

### 新增檔案
- `lib/core/tutorial/tutorial_service.dart` — 追蹤是否已完成教學、寫入 Hive
- `lib/features/tutorial/presentation/tutorial_overlay.dart` — 全屏浮層，帶步驟指示

### 修改
- `GameHomeScreen` — 偵測未完成教學，強制顯示 overlay
- `app_shell.dart` — app 啟動時呼叫 `TutorialService.checkAndShow`
- `CatchLogState` — 強制的 tutorial catch（魚種固定為 #010，不可跳過）

### 流程
1. App 啟動 → 檢查 Hive `tutorial_completed = false`
2. 顯示浮層步驟：
   - 步驟 1：介紹圖鑑（雙手勢操作說明）
   - 步驟 2：示範 GPS 作釣
   - 步驟 3：強制作魚一次（魚種固定 #010，UI 禁用其他選擇）
   - 步驟 4：完成彈出「又係依D!」文字
3. 完成後寫入 Hive `tutorial_completed = true`，解鎖 #010（#010 本身在教學後才可被捕捉）
4. #010 在教學完成前：圖鑑顯示為上鎖狀態，教學中禁止捕捉其他魚

### 常量
- Tutorial fish ID: `fish-010`

---

## 功能 2：公告系統

### 新增檔案
- `lib/core/announcement/announcement_service.dart` — 讀取/寫入 Hive（`last_announcement_seen_date`）
- `lib/features/announcement/presentation/announcement_modal.dart` — 公告内容 Card + 關閉按鈕
- `lib/core/announcement/announcement_data.dart` — 公告內容模型（可擴充）

### 修改
- `GameHomeScreen` — 每天首次開啟，檢查 `last_announcement_seen_date != today`，顯示公告 Icon + 紅色 badge

### 紅點邏輯
- Hive key: `last_announcement_seen_date`（格式 `YYYY-MM-DD`）
- 比較：當日日期 != 儲存日期 → 顯示紅點
- 用戶看過公告後，寫入今日日期

### 獎金
- 公告內容包含「首次查看可得金幣獎勵」文案
- 關閉公告時，通過 `ProfileWalletService.addCoins(50)` 發放

---

## 功能 3：船家服務

### 新增檔案
- `lib/core/shop/boat_vendor_service.dart` — 船家狀態（持有哪個船家、冷卻時間）
- `lib/domain/boat_vendor.dart` — 船家模型（id, name, zone, dialogues, price, duration）
- `lib/features/shop/presentation/boat_vendor_shop_card.dart` — 商店內船家卡片

### 船家資料
```
4Sea:
  name: 4Sea
  zone: 東水一帶
  dialogues: ["大過細個條", "依度新鮮架", "收起，車前少少", "收起，車返後少少", "落得"]
  price: 硬幣定價待定
  spot_count: 5

豪Dee:
  name: 豪Dee
  zone: 青馬一帶
  dialogues: ["唉，收收收", "唉，試試"]
  price: 硬幣定價待定
  spot_count: 5
```

### 商店 UI
- 在現有商店頁加入「船家服務」section
- 每個船家顯示為一張卡：名字、區域、價格、「租用」按鈕

### 遊戲效果
- 租用後，該水域內 5 個特定座標（見下）在地圖顯示為「船家專用點」
- 站在專用點上，**跳過 GPS 距離檢查**，直接可以作魚（相當於到達該水域）
- 冷卻時間：待定（可選 24 小時或單次）

### 地圖整合
- `GameMapScreen` 或 `CheckpointMapPainter`：
  - 如有用戶的 active boat vendor，疊加 5 個船家專用 spot markers
  - 船家 markers 為不同颜色（如藍色船錨 icon）
  - 站在船家 spot 內，按「作魚」→ 通過 boat service 驗證 → 放行

### BoatVendorService
```dart
class BoatVendorService {
  static Future<void> rent(String vendorId);
  static bool isActive(String vendorId);
  static List<LatLng> getVendorSpots(String vendorId); // 5 個座標
  static String randomDialogue(String vendorId);
}
```

### 座標（待定，可暫用已知水域座標附近）
- 東水：可用現有東水 checkpoint 附近微調
- 青馬：可用現有青馬 checkpoint 附近微調
- 實作時先做 stub 座標，正式版由你提供真實座標替換

---

## 優先順序

1. **Tutorial** — 獨立，封閉影響最少，可先驗證
2. **Announcement** — 簡單，UI 改動少
3. **Boat Vendor** — 最複雜，涉及地圖、遊戲狀態、對話

---

## 測試策略
- `test/tutorial_service_test.dart`
- `test/boat_vendor_service_test.dart`
- Widget test for tutorial overlay