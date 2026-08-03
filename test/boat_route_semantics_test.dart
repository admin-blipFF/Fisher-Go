import 'package:flutter_test/flutter_test.dart';

import 'package:fishergo/features/boat/presentation/boat_route_semantics.dart';

void main() {
  test('route progress semantics include vendor, count, and state', () {
    expect(
      boatRouteProgressSemanticsLabel(
        vendorName: '4Sea',
        zoneName: '東水一帶',
        completed: 2,
        total: 5,
        allDone: false,
      ),
      '船線 4Sea，東水一帶，已完成 2/5 個釣點，進行中',
    );
    expect(
      boatRouteProgressSemanticsLabel(
        vendorName: '豪Dee',
        zoneName: '青馬一帶',
        completed: 2,
        total: 2,
        allDone: true,
      ),
      '船線 豪Dee，青馬一帶，已完成 2/2 個釣點，全部完成',
    );
  });

  test('spot semantics distinguish available and completed states', () {
    expect(
      boatRouteSpotSemanticsLabel(
        spotName: '中環10號碼頭',
        status: '可作釣',
        canFish: true,
      ),
      '釣點 中環10號碼頭，可作釣，按作釣開始釣魚',
    );
    expect(
      boatRouteSpotSemanticsLabel(
        spotName: '九龍公眾碼頭',
        status: '成功',
        canFish: false,
      ),
      '釣點 九龍公眾碼頭，成功，已完成',
    );
  });
}
