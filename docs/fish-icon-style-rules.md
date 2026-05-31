# FisherGO 魚圖示風格規範

更新日期：2026-05-31
來源：與產品負責人（Kai Lok）確認

## A. 魚身紋路規範（已確認）
### 釘公（ID 035）
- 魚身紋路必須為「由頭至尾」走向的橫紋（head-to-tail horizontal bands）。
- 不接受垂直條紋或斜向主紋作為主視覺。

## B. 背景色語義（正式版）

### 中文規則
- 普通／常見海魚：藍色背景
- 危險／有毒魚：紅色背景
- 稀有魚：金色背景
- 高價值魚：紫色背景
- 小型魚：淺青／淡藍背景
- 深水／夜行魚：深藍黑背景

### English mapping
- Common/normal sea fish: ocean blue
- Dangerous/venomous/handle-with-care: red or deep red
- Rare: gold
- High-value/prized market fish: purple or blue-purple
- Small fish / baitfish / school fish: light cyan or pale blue
- Deep-sea/night: dark indigo/navy

## C. 分類衝突優先級（已確認）
- 先稀有（Rare first）。
- 即：當一條魚同時符合多個分類時，優先套用「稀有魚：金色背景」。

## D. 套用範圍
- `assets/fish/icons/generated/*.png`
- 後續批量重製時需按本規範檢查。

## D. 驗收檢查清單
- [ ] 紋路方向：是否符合品種特徵（如 035 必須頭到尾橫紋）
- [ ] 背景顏色：是否符合該魚分類語義
- [ ] 非稀有魚是否錯用金色／紫色
- [ ] 視覺一致性：與同分類魚群風格一致
