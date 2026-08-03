import '../domain/fish_catalog_view_model.dart';

String fishEncyclopediaProgressSemanticsLabel({
  required int unlocked,
  required int total,
  required int verified,
}) {
  final safeTotal = total < 0 ? 0 : total;
  final safeUnlocked = unlocked.clamp(0, safeTotal).toInt();
  final safeVerified = verified < 0 ? 0 : verified;
  final percentage =
      safeTotal == 0 ? 0 : ((safeUnlocked / safeTotal) * 100).round();
  return '圖鑑解鎖進度：$safeUnlocked/$safeTotal，$percentage%，'
      '魚鈎認證 $safeVerified 個';
}

String fishEncyclopediaEmptyStateSemanticsLabel(FishCatalogFilter filter) {
  final filterLabel = switch (filter) {
    FishCatalogFilter.all => '全部',
    FishCatalogFilter.unlocked => '已釣獲',
    FishCatalogFilter.verified => '真實認證',
  };
  return '圖鑑篩選：$filterLabel，這個分類暫時沒有魚種';
}
