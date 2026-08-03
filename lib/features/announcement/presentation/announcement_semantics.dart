String announcementRewardSemanticsLabel({
  required bool claimed,
  required int rewardCoins,
}) {
  return claimed
      ? '每日公告獎勵：$rewardCoins 金幣，今日已領取'
      : '每日公告獎勵：$rewardCoins 金幣，尚未領取';
}

String announcementClaimSemanticsLabel(int rewardCoins) {
  return '領取每日公告獎勵：$rewardCoins 金幣';
}

String announcementClaimedSemanticsLabel(int rewardCoins) {
  return '每日公告獎勵已領取：$rewardCoins 金幣';
}
