import 'fish_collection_status.dart';

/// One source of truth for the player-facing collection rules.
class FishDiscoveryCopy {
  const FishDiscoveryCopy._();

  static String statusLabel(FishDiscoveryStatus status) {
    switch (status) {
      case FishDiscoveryStatus.unknown:
        return '未發現';
      case FishDiscoveryStatus.encountered:
        return '已遇見 · 等待釣獲';
      case FishDiscoveryStatus.gameCaught:
        return '遊戲釣獲 · 全彩圖示';
      case FishDiscoveryStatus.verifiedRealCatch:
        return '真實釣獲 · 魚鈎認證';
    }
  }

  static String detailHint(FishDiscoveryStatus status) {
    switch (status) {
      case FishDiscoveryStatus.unknown:
        return '完成一次小遊戲釣獲後，解鎖魚名和全彩圖示。';
      case FishDiscoveryStatus.encountered:
        return '已在水域遇見，完成小遊戲釣獲後解鎖全彩圖示。';
      case FishDiscoveryStatus.gameCaught:
        return '已由小遊戲釣獲並解鎖全彩圖示；上載及確認真實相片後會加上魚鈎和比賽資格。';
      case FishDiscoveryStatus.verifiedRealCatch:
        return '真實相片已確認，魚鈎認證、完整生態資料及比賽資格已解鎖。';
    }
  }

  static String tutorialRule() => '小遊戲釣獲會解鎖全彩圖示；真實相片確認後會加上魚鈎認證及完整資料。';

  static String competitionRule() => '上載並確認真實魚獲相片，才會獲得魚鈎認證及比賽資格。';
}
