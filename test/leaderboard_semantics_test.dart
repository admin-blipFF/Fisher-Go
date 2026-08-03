import 'package:fishergo/features/leaderboard/presentation/leaderboard_semantics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('leaderboard dynamic states have explicit announcements', () {
    expect(leaderboardLoadingSemanticsLabel(), contains('載入'));
    expect(leaderboardErrorSemanticsLabel(), contains('重試'));
    expect(leaderboardEmptySemanticsLabel(), contains('已驗證魚獲'));
    expect(leaderboardSectionSemanticsLabel(3), '真實捕獲排行榜，共 3 項');
  });

  test('leaderboard row semantics include rank and catch details', () {
    expect(
      leaderboardRowSemanticsLabel(
        rank: 2,
        fishName: '烏頭',
        lengthCm: 12.3,
        rarityRank: 3,
        verifiedDate: '2026-08-03',
      ),
      '第 2 名，烏頭，12.3 cm，稀有度 3，2026-08-03',
    );
    expect(
      leaderboardRowSemanticsLabel(
        rank: 1,
        fishName: '未知魚',
        lengthCm: null,
        rarityRank: 1,
        verifiedDate: '驗證時間未記錄',
      ),
      '第 1 名，未知魚，未填長度，稀有度 1，驗證時間未記錄',
    );
  });
}
