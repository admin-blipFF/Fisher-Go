import 'package:fishergo/features/game_home/domain/fishing_strike_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FishingStrikeRules', () {
    test('rejects strikes before the bite has started', () {
      final result = FishingStrikeRules.evaluate(
        biteElapsedSeconds: -0.1,
        biteWindowSeconds: 1.4,
        difficulty: 2,
      );

      expect(result.isSuccess, isFalse);
      expect(result.reason, FishingStrikeFailReason.tooEarly);
    });

    test('accepts strikes inside the bite timing window', () {
      final result = FishingStrikeRules.evaluate(
        biteElapsedSeconds: 0.55,
        biteWindowSeconds: 1.4,
        difficulty: 2,
      );

      expect(result.isSuccess, isTrue);
      expect(result.reason, isNull);
    });

    test('narrows the valid timing window for difficult fish', () {
      final easy = FishingStrikeRules.evaluate(
        biteElapsedSeconds: 0.92,
        biteWindowSeconds: 1.4,
        difficulty: 1,
      );
      final hard = FishingStrikeRules.evaluate(
        biteElapsedSeconds: 0.92,
        biteWindowSeconds: 1.4,
        difficulty: 5,
      );

      expect(easy.isSuccess, isTrue);
      expect(hard.isSuccess, isFalse);
      expect(hard.reason, FishingStrikeFailReason.tooLate);
    });

    test('rejects strikes after the bite window ends', () {
      final result = FishingStrikeRules.evaluate(
        biteElapsedSeconds: 1.45,
        biteWindowSeconds: 1.4,
        difficulty: 1,
      );

      expect(result.isSuccess, isFalse);
      expect(result.reason, FishingStrikeFailReason.tooLate);
    });
  });
}
