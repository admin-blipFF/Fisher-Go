import 'package:fishergo/features/game_home/domain/fishing_event_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FishingEventRules', () {
    test('classifies local fishing time windows at boundaries', () {
      expect(
        FishingEventRules.timeWindowFor(DateTime(2026, 6, 24, 5, 0)),
        FishingTimeWindow.morning,
      );
      expect(
        FishingEventRules.timeWindowFor(DateTime(2026, 6, 24, 9, 59)),
        FishingTimeWindow.morning,
      );
      expect(
        FishingEventRules.timeWindowFor(DateTime(2026, 6, 24, 10, 0)),
        FishingTimeWindow.daytime,
      );
      expect(
        FishingEventRules.timeWindowFor(DateTime(2026, 6, 24, 16, 59)),
        FishingTimeWindow.daytime,
      );
      expect(
        FishingEventRules.timeWindowFor(DateTime(2026, 6, 24, 17, 0)),
        FishingTimeWindow.dusk,
      );
      expect(
        FishingEventRules.timeWindowFor(DateTime(2026, 6, 24, 19, 59)),
        FishingTimeWindow.dusk,
      );
      expect(
        FishingEventRules.timeWindowFor(DateTime(2026, 6, 24, 20, 0)),
        FishingTimeWindow.night,
      );
      expect(
        FishingEventRules.timeWindowFor(DateTime(2026, 6, 24, 4, 59)),
        FishingTimeWindow.night,
      );
    });

    test('shows Tsing Ma night event label only at night', () {
      expect(
        FishingEventRules.activeEventLabels(
          spotName: '青馬大橋橋底',
          now: DateTime(2026, 6, 24, 20, 0),
        ),
        equals(['夜水：石斑 / 海塘蝨提升']),
      );
      expect(
        FishingEventRules.activeEventLabels(
          spotName: '青馬大橋橋底',
          now: DateTime(2026, 6, 24, 4, 59),
        ),
        equals(['夜水：石斑 / 海塘蝨提升']),
      );
      expect(
        FishingEventRules.activeEventLabels(
          spotName: '青馬大橋橋底',
          now: DateTime(2026, 6, 24, 19, 59),
        ),
        isEmpty,
      );
      expect(
        FishingEventRules.activeEventLabels(
          spotName: '青馬大橋橋底',
          now: DateTime(2026, 6, 24, 5, 0),
        ),
        isEmpty,
      );
    });

    test('shows East Water dusk event label only at dusk', () {
      expect(
        FishingEventRules.activeEventLabels(
          spotName: '東龍洲碼頭',
          now: DateTime(2026, 6, 24, 17, 0),
        ),
        equals(['黃昏：池仔 / 黃雞魚提升']),
      );
      expect(
        FishingEventRules.activeEventLabels(
          spotName: '東龍洲碼頭',
          now: DateTime(2026, 6, 24, 19, 59),
        ),
        equals(['黃昏：池仔 / 黃雞魚提升']),
      );
      expect(
        FishingEventRules.activeEventLabels(
          spotName: '東龍洲碼頭',
          now: DateTime(2026, 6, 24, 16, 59),
        ),
        isEmpty,
      );
      expect(
        FishingEventRules.activeEventLabels(
          spotName: '東龍洲碼頭',
          now: DateTime(2026, 6, 24, 20, 0),
        ),
        isEmpty,
      );
    });

    test('shows inner sea morning mullet label only in morning', () {
      expect(
        FishingEventRules.activeEventLabels(
          spotName: '三門仔村碼頭',
          now: DateTime(2026, 6, 24, 5, 0),
        ),
        equals(['早水：烏頭提升']),
      );
      expect(
        FishingEventRules.activeEventLabels(
          spotName: '三門仔村碼頭',
          now: DateTime(2026, 6, 24, 9, 59),
        ),
        equals(['早水：烏頭提升']),
      );
      expect(
        FishingEventRules.activeEventLabels(
          spotName: '三門仔村碼頭',
          now: DateTime(2026, 6, 24, 10, 0),
        ),
        isEmpty,
      );
      expect(
        FishingEventRules.activeEventLabels(
          spotName: '三門仔村碼頭',
          now: DateTime(2026, 6, 24, 4, 59),
        ),
        isEmpty,
      );
    });

    test('shows runway bream label in morning and dusk only', () {
      expect(
        FishingEventRules.activeEventLabels(
          spotName: '赤鱲角機場跑道尾',
          now: DateTime(2026, 6, 24, 5, 0),
        ),
        equals(['早晚：立魚提升']),
      );
      expect(
        FishingEventRules.activeEventLabels(
          spotName: '赤鱲角機場跑道尾',
          now: DateTime(2026, 6, 24, 9, 59),
        ),
        equals(['早晚：立魚提升']),
      );
      expect(
        FishingEventRules.activeEventLabels(
          spotName: '赤鱲角機場跑道尾',
          now: DateTime(2026, 6, 24, 17, 0),
        ),
        equals(['早晚：立魚提升']),
      );
      expect(
        FishingEventRules.activeEventLabels(
          spotName: '赤鱲角機場跑道尾',
          now: DateTime(2026, 6, 24, 19, 59),
        ),
        equals(['早晚：立魚提升']),
      );
      expect(
        FishingEventRules.activeEventLabels(
          spotName: '赤鱲角機場跑道尾',
          now: DateTime(2026, 6, 24, 10, 0),
        ),
        isEmpty,
      );
      expect(
        FishingEventRules.activeEventLabels(
          spotName: '赤鱲角機場跑道尾',
          now: DateTime(2026, 6, 24, 16, 59),
        ),
        isEmpty,
      );
      expect(
        FishingEventRules.activeEventLabels(
          spotName: '赤鱲角機場跑道尾',
          now: DateTime(2026, 6, 24, 20, 0),
        ),
        isEmpty,
      );
      expect(
        FishingEventRules.activeEventLabels(
          spotName: '赤鱲角機場跑道尾',
          now: DateTime(2026, 6, 24, 4, 59),
        ),
        isEmpty,
      );
    });

    test('boosts only grouper and catfish during Tsing Ma night fishing', () {
      final night = DateTime(2026, 6, 24, 22);

      expect(
        FishingEventRules.eventMultiplier(
          spotName: '青馬大橋橋底',
          fishName: '石斑魚',
          fishId: 'fish-073',
          now: night,
        ),
        2.0,
      );
      expect(
        FishingEventRules.eventMultiplier(
          spotName: '馬灣碼頭',
          fishName: '海塘蝨',
          fishId: 'fish-069',
          now: night,
        ),
        2.0,
      );
      expect(
        FishingEventRules.eventMultiplier(
          spotName: '馬灣碼頭',
          fishName: '烏頭',
          fishId: 'fish-063',
          now: night,
        ),
        1.0,
      );
    });

    test('boosts matching East Water fish only at dusk', () {
      final dusk = DateTime(2026, 6, 24, 18);

      expect(
        FishingEventRules.eventMultiplier(
          spotName: '東龍洲碼頭',
          fishName: '深海沙丁',
          fishId: 'fish-131',
          now: dusk,
        ),
        1.8,
      );
      expect(
        FishingEventRules.eventMultiplier(
          spotName: '西貢東水',
          fishName: '黃雞魚',
          fishId: 'fish-101',
          now: dusk,
        ),
        1.8,
      );
      expect(
        FishingEventRules.eventMultiplier(
          spotName: '東龍洲碼頭',
          fishName: '紅鱲',
          fishId: 'fish-110',
          now: dusk,
        ),
        1.8,
      );
      expect(
        FishingEventRules.eventMultiplier(
          spotName: '西貢東水',
          fishName: '石斑魚',
          fishId: 'fish-073',
          now: dusk,
        ),
        1.0,
      );
      expect(
        FishingEventRules.eventMultiplier(
          spotName: '西貢東水',
          fishName: '黃雞魚',
          fishId: 'fish-101',
          now: DateTime(2026, 6, 24, 13),
        ),
        1.0,
      );
    });

    test('boosts inner sea mullet only during morning', () {
      expect(
        FishingEventRules.eventMultiplier(
          spotName: '三門仔村碼頭',
          fishName: '烏頭',
          fishId: 'fish-063',
          now: DateTime(2026, 6, 24, 7),
        ),
        1.8,
      );
      expect(
        FishingEventRules.eventMultiplier(
          spotName: '三門仔村碼頭',
          fishName: '石斑魚',
          fishId: 'fish-073',
          now: DateTime(2026, 6, 24, 7),
        ),
        1.0,
      );
      expect(
        FishingEventRules.eventMultiplier(
          spotName: '三門仔村碼頭',
          fishName: '烏頭',
          fishId: 'fish-063',
          now: DateTime(2026, 6, 24, 13),
        ),
        1.0,
      );
    });

    test('boosts runway bream during morning and dusk only', () {
      expect(
        FishingEventRules.eventMultiplier(
          spotName: '赤鱲角機場跑道尾',
          fishName: '黃腳鱲',
          fishId: 'fish-109',
          now: DateTime(2026, 6, 24, 6),
        ),
        1.6,
      );
      expect(
        FishingEventRules.eventMultiplier(
          spotName: '赤鱲角機場跑道尾',
          fishName: '黃腳鱲',
          fishId: 'fish-109',
          now: DateTime(2026, 6, 24, 18),
        ),
        1.6,
      );
      expect(
        FishingEventRules.eventMultiplier(
          spotName: '赤鱲角機場跑道尾',
          fishName: '黃腳鱲',
          fishId: 'fish-109',
          now: DateTime(2026, 6, 24, 13),
        ),
        1.0,
      );
      expect(
        FishingEventRules.eventMultiplier(
          spotName: '赤鱲角機場跑道尾',
          fishName: '烏頭',
          fishId: 'fish-063',
          now: DateTime(2026, 6, 24, 18),
        ),
        1.0,
      );
    });
  });
}
