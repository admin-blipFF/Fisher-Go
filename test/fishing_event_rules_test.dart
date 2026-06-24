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
          now: DateTime(2026, 6, 24, 22),
        ),
        contains('夜水：石斑 / 海塘蝨提升'),
      );
      expect(
        FishingEventRules.activeEventLabels(
          spotName: '青馬大橋橋底',
          now: DateTime(2026, 6, 24, 14),
        ),
        isEmpty,
      );
    });

    test('shows East Water dusk event label only at dusk', () {
      expect(
        FishingEventRules.activeEventLabels(
          spotName: '東龍洲碼頭',
          now: DateTime(2026, 6, 24, 18),
        ),
        contains('黃昏：池仔 / 黃雞魚提升'),
      );
      expect(
        FishingEventRules.activeEventLabels(
          spotName: '東龍洲碼頭',
          now: DateTime(2026, 6, 24, 11),
        ),
        isEmpty,
      );
    });

    test('shows inner sea morning mullet label only in morning', () {
      expect(
        FishingEventRules.activeEventLabels(
          spotName: '三門仔村碼頭',
          now: DateTime(2026, 6, 24, 7),
        ),
        contains('早水：烏頭提升'),
      );
      expect(
        FishingEventRules.activeEventLabels(
          spotName: '三門仔村碼頭',
          now: DateTime(2026, 6, 24, 20),
        ),
        isEmpty,
      );
    });

    test('shows runway bream label in morning and dusk only', () {
      expect(
        FishingEventRules.activeEventLabels(
          spotName: '赤鱲角機場跑道尾',
          now: DateTime(2026, 6, 24, 6),
        ),
        contains('早晚：立魚提升'),
      );
      expect(
        FishingEventRules.activeEventLabels(
          spotName: '赤鱲角機場跑道尾',
          now: DateTime(2026, 6, 24, 18),
        ),
        contains('早晚：立魚提升'),
      );
      expect(
        FishingEventRules.activeEventLabels(
          spotName: '赤鱲角機場跑道尾',
          now: DateTime(2026, 6, 24, 13),
        ),
        isEmpty,
      );
    });
  });
}
