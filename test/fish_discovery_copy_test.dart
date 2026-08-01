import 'package:flutter_test/flutter_test.dart';

import 'package:fishergo/features/fish/domain/fish_collection_copy.dart';
import 'package:fishergo/features/fish/domain/fish_collection_status.dart';

void main() {
  test('game caught copy describes a full-color game unlock', () {
    expect(
      FishDiscoveryCopy.statusLabel(FishDiscoveryStatus.gameCaught),
      '遊戲釣獲 · 全彩圖示',
    );
    expect(
      FishDiscoveryCopy.detailHint(FishDiscoveryStatus.gameCaught),
      contains('全彩圖示'),
    );
    expect(
      FishDiscoveryCopy.detailHint(FishDiscoveryStatus.gameCaught),
      contains('魚鈎'),
    );
  });

  test('verified catch copy reserves the hook badge for a real photo', () {
    expect(
      FishDiscoveryCopy.statusLabel(FishDiscoveryStatus.verifiedRealCatch),
      '真實釣獲 · 魚鈎認證',
    );
    expect(
      FishDiscoveryCopy.detailHint(FishDiscoveryStatus.verifiedRealCatch),
      contains('比賽資格'),
    );
  });

  test('unknown copy does not reveal species identity', () {
    expect(
      FishDiscoveryCopy.statusLabel(FishDiscoveryStatus.unknown),
      '未發現',
    );
    expect(
      FishDiscoveryCopy.detailHint(FishDiscoveryStatus.unknown),
      contains('小遊戲釣獲'),
    );
  });
}
