import 'package:fishergo/features/game_home/domain/fishing_bite_controller.dart';
import 'package:fishergo/features/game_home/domain/fishing_strike_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FishingBiteController', () {
    test('waits for the configured bite delay before becoming ready', () {
      final controller = FishingBiteController(
        waitSeconds: 0.15,
        biteWindowSeconds: 0.2,
        tickSeconds: 0.05,
      );

      expect(controller.state.phase, FishingBitePhase.waiting);
      controller.advance();
      controller.advance();
      expect(controller.state.phase, FishingBitePhase.waiting);

      controller.advance();
      expect(controller.state.phase, FishingBitePhase.ready);
      expect(controller.state.elapsedSeconds, 0);
    });

    test('accepts a strike during the bite window', () {
      final controller = FishingBiteController(
        waitSeconds: 0,
        biteWindowSeconds: 0.2,
        tickSeconds: 0.05,
      )..advance();

      controller.advance();
      final result = controller.strike(difficulty: 1);

      expect(result.isSuccess, isTrue);
      expect(controller.state.phase, FishingBitePhase.struck);
    });

    test('returns too early when the rod is pulled before the bite', () {
      final controller = FishingBiteController(
        waitSeconds: 0.3,
        biteWindowSeconds: 0.2,
        tickSeconds: 0.05,
      );

      final result = controller.strike(difficulty: 2);

      expect(result.isSuccess, isFalse);
      expect(result.reason, FishingStrikeFailReason.tooEarly);
      expect(controller.state.phase, FishingBitePhase.missed);
    });

    test('misses the bite after the window closes', () {
      final controller = FishingBiteController(
        waitSeconds: 0,
        biteWindowSeconds: 0.1,
        tickSeconds: 0.05,
      );

      controller.advance();
      controller.advance();
      controller.advance();
      controller.advance();

      expect(controller.state.phase, FishingBitePhase.missed);
      expect(
        controller.strike(difficulty: 1).reason,
        FishingStrikeFailReason.tooLate,
      );
    });
  });
}
