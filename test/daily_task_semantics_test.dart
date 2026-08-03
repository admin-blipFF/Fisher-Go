import 'package:flutter_test/flutter_test.dart';

import 'package:fishergo/features/profile/presentation/daily_task_semantics.dart';

void main() {
  test('daily task label reports progress, state, and reward', () {
    expect(
      dailyTaskSemanticsLabel(
        title: '今日釣到 2 條魚',
        current: 2,
        target: 2,
        rewardCoins: 20,
        isCompleted: true,
        isClaimed: false,
        canClaim: true,
      ),
      '每日任務：今日釣到 2 條魚，進度 2/2，已完成，可領取獎勵，獎勵 20 金幣',
    );

    expect(
      dailyTaskSemanticsLabel(
        title: '今日解鎖 2 種魚',
        current: 1,
        target: 2,
        rewardCoins: 30,
        isCompleted: false,
        isClaimed: false,
        canClaim: false,
      ),
      '每日任務：今日解鎖 2 種魚，進度 1/2，進行中，獎勵 30 金幣',
    );

    expect(
      dailyTaskSemanticsLabel(
        title: '今日釣到 2 條魚',
        current: 2,
        target: 2,
        rewardCoins: 20,
        isCompleted: true,
        isClaimed: true,
        canClaim: false,
      ),
      '每日任務：今日釣到 2 條魚，進度 2/2，已領取，獎勵 20 金幣',
    );
  });

  test('daily task controls expose distinct progress and claim labels', () {
    expect(
      dailyTaskProgressSemanticsLabel(
        title: '今日釣到 2 條魚',
        current: 1,
        target: 2,
      ),
      '每日任務進度：今日釣到 2 條魚，1/2',
    );
    expect(
      dailyTaskClaimSemanticsLabel(
        title: '今日釣到 2 條魚',
        rewardCoins: 20,
      ),
      '領取每日任務獎勵：今日釣到 2 條魚，20 金幣',
    );
    expect(
      dailyTaskClaimedSemanticsLabel(
        title: '今日釣到 2 條魚',
        rewardCoins: 20,
      ),
      '每日任務獎勵已領取：今日釣到 2 條魚，20 金幣',
    );
  });
}
