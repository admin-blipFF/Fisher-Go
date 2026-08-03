String dailyTaskSemanticsLabel({
  required String title,
  required int current,
  required int target,
  required int rewardCoins,
  required bool isCompleted,
  required bool isClaimed,
  required bool canClaim,
}) {
  final status = canClaim
      ? '已完成，可領取獎勵'
      : isClaimed
          ? '已領取'
          : isCompleted
              ? '已完成'
              : '進行中';
  return '每日任務：$title，進度 $current/$target，$status，獎勵 $rewardCoins 金幣';
}

String dailyTaskProgressSemanticsLabel({
  required String title,
  required int current,
  required int target,
}) {
  return '每日任務進度：$title，$current/$target';
}

String dailyTaskClaimSemanticsLabel({
  required String title,
  required int rewardCoins,
}) {
  return '領取每日任務獎勵：$title，$rewardCoins 金幣';
}

String dailyTaskClaimedSemanticsLabel({
  required String title,
  required int rewardCoins,
}) {
  return '每日任務獎勵已領取：$title，$rewardCoins 金幣';
}
