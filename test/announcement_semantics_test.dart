import 'package:flutter_test/flutter_test.dart';

import 'package:fishergo/features/announcement/presentation/announcement_semantics.dart';

void main() {
  test('announcement reward state includes claim status and amount', () {
    expect(
      announcementRewardSemanticsLabel(
        claimed: false,
        rewardCoins: 15,
      ),
      '每日公告獎勵：15 金幣，尚未領取',
    );
    expect(
      announcementRewardSemanticsLabel(
        claimed: true,
        rewardCoins: 15,
      ),
      '每日公告獎勵：15 金幣，今日已領取',
    );
  });

  test('announcement actions identify the reward they operate on', () {
    expect(
      announcementClaimSemanticsLabel(15),
      '領取每日公告獎勵：15 金幣',
    );
    expect(
      announcementClaimedSemanticsLabel(15),
      '每日公告獎勵已領取：15 金幣',
    );
  });
}
