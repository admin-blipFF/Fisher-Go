String boatRouteProgressSemanticsLabel({
  required String vendorName,
  required String zoneName,
  required int completed,
  required int total,
  required bool allDone,
}) {
  final safeTotal = total < 0 ? 0 : total;
  final safeCompleted = completed.clamp(0, safeTotal).toInt();
  final state = allDone ? '全部完成' : '進行中';
  return '船線 $vendorName，$zoneName，已完成 '
      '$safeCompleted/$safeTotal 個釣點，$state';
}

String boatRouteStatusSemanticsLabel(String? status) {
  return switch (status) {
    'success' => '成功，已完成',
    'fail' => '失敗，已完成',
    'done' => '已完成',
    _ => '可作釣',
  };
}

String boatRouteSpotSemanticsLabel({
  required String spotName,
  required String status,
  required bool canFish,
}) {
  final action = canFish ? '，按作釣開始釣魚' : '';
  final completion = canFish ? '' : '，已完成';
  return '釣點 $spotName，$status$completion$action';
}
