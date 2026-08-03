String leaderboardLoadingSemanticsLabel() => '正在載入真實捕獲排行榜';

String leaderboardErrorSemanticsLabel() => '排行榜暫時無法載入，可按重試';

String leaderboardEmptySemanticsLabel() => '暫無已驗證魚獲';

String leaderboardSectionSemanticsLabel(int count) => '真實捕獲排行榜，共 $count 項';

String leaderboardRowSemanticsLabel({
  required int rank,
  required String fishName,
  required double? lengthCm,
  required int rarityRank,
  required String verifiedDate,
}) {
  final length =
      lengthCm == null ? '未填長度' : '${lengthCm.toStringAsFixed(1)} cm';
  return '第 $rank 名，$fishName，$length，稀有度 $rarityRank，$verifiedDate';
}
