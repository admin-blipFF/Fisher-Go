import 'package:fishergo/features/game_home/domain/fishing_spawn_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FishingSpawnRules', () {
    test('boosts bream around north water and Tung Chung runway spots', () {
      expect(
        FishingSpawnRules.locationMultiplier(
          spotName: '赤鱲角機場跑道尾',
          fishName: '黃腳鱲',
          fishId: 'fish-109',
        ),
        greaterThan(1),
      );
      expect(
        FishingSpawnRules.locationMultiplier(
          spotName: '東平洲碼頭',
          fishName: '赤鱲',
          fishId: 'fish-103',
        ),
        greaterThan(1),
      );
    });

    test('boosts mullet in Sam Mun Tsai and Tai Po inner water', () {
      expect(
        FishingSpawnRules.locationMultiplier(
          spotName: '三門仔村碼頭',
          fishName: '草魚',
          fishId: 'fish-063',
        ),
        greaterThan(1),
      );
      expect(
        FishingSpawnRules.locationMultiplier(
          spotName: '大埔內海',
          fishName: '大眼烏頭',
          fishId: 'fish-067',
        ),
        greaterThan(1),
      );
    });

    test('boosts grouper and catfish around Tsing Ma waters', () {
      expect(
        FishingSpawnRules.locationMultiplier(
          spotName: '青馬大橋橋底',
          fishName: '石斑魚',
          fishId: 'fish-073',
        ),
        greaterThan(1),
      );
      expect(
        FishingSpawnRules.locationMultiplier(
          spotName: '馬灣碼頭',
          fishName: '海塘蝨',
          fishId: 'fish-069',
        ),
        greaterThan(1),
      );
    });

    test('boosts scad, red bream, and chicken fish in east water', () {
      expect(
        FishingSpawnRules.locationMultiplier(
          spotName: '東龍洲碼頭',
          fishName: '深海沙丁',
          fishId: 'fish-131',
        ),
        greaterThan(1),
      );
      expect(
        FishingSpawnRules.locationMultiplier(
          spotName: '西貢東水',
          fishName: '黃雞魚',
          fishId: 'fish-101',
        ),
        greaterThan(1),
      );
      expect(
        FishingSpawnRules.locationMultiplier(
          spotName: '果洲群島',
          fishName: '赤鱲',
          fishId: 'fish-103',
        ),
        greaterThan(1),
      );
    });

    test('blocks location-special fish outside their matching waters', () {
      expect(
        FishingSpawnRules.locationMultiplier(
          spotName: '中環碼頭',
          fishName: '石斑魚',
          fishId: 'fish-073',
        ),
        0,
      );
      expect(
        FishingSpawnRules.locationMultiplier(
          spotName: '三門仔村碼頭',
          fishName: '石斑魚',
          fishId: 'fish-073',
        ),
        0,
      );
    });

    test('keeps generic fish available at unrelated spots', () {
      expect(
        FishingSpawnRules.locationMultiplier(
          spotName: '中環碼頭',
          fishName: '藍鰭鮪',
          fishId: 'fish-153',
        ),
        1,
      );
    });

    test('summarizes visible local fish intel for matching spots', () {
      expect(
        FishingSpawnRules.spotIntelLabels('赤鱲角機場跑道尾'),
        containsAll(['立魚', '黃腳鱲', '赤鱲']),
      );
      expect(
        FishingSpawnRules.spotIntelLabels('三門仔村碼頭'),
        containsAll(['烏頭', '大眼烏頭']),
      );
      expect(
        FishingSpawnRules.spotIntelLabels('馬灣碼頭'),
        containsAll(['石斑', '海塘蝨']),
      );
      expect(
        FishingSpawnRules.spotIntelLabels('東龍洲碼頭'),
        containsAll(['池仔', '赤鱲', '黃雞魚']),
      );
      expect(FishingSpawnRules.spotIntelLabels('中環碼頭'), isEmpty);
    });
  });
}
