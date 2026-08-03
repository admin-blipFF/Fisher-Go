String catchLogSpotSemanticsLabel(int count) {
  return count == 1 ? '釣點' : '$count 個釣點';
}

String catchLogRadarSemanticsLabel(bool autoEnabled) {
  return autoEnabled ? '自動打點已啟用，切換為手動' : '自動打點已停用，切換為自動';
}
