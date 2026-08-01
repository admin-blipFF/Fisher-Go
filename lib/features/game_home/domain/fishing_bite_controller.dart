import 'fishing_strike_rules.dart';

/// The small state machine that runs between casting and the tension fight.
///
/// Keeping this separate from the overlay makes the timing rules deterministic
/// in tests and leaves haptics, animation, and copy as presentation concerns.
enum FishingBitePhase { waiting, ready, missed, struck }

class FishingBiteState {
  const FishingBiteState({
    required this.phase,
    required this.elapsedSeconds,
  });

  final FishingBitePhase phase;
  final double elapsedSeconds;
}

class FishingBiteController {
  FishingBiteController({
    required double waitSeconds,
    required double biteWindowSeconds,
    double tickSeconds = 0.05,
  })  : _waitSeconds = waitSeconds.clamp(0, double.infinity).toDouble(),
        _biteWindowSeconds =
            biteWindowSeconds.clamp(0, double.infinity).toDouble(),
        _tickSeconds = tickSeconds.clamp(0.001, double.infinity).toDouble(),
        _state = const FishingBiteState(
          phase: FishingBitePhase.waiting,
          elapsedSeconds: 0,
        );

  final double _waitSeconds;
  final double _biteWindowSeconds;
  final double _tickSeconds;
  FishingBiteState _state;
  double _waitElapsedSeconds = 0;

  FishingBiteState get state => _state;

  /// Advances one game tick and returns the new state.
  FishingBiteState advance() {
    switch (_state.phase) {
      case FishingBitePhase.waiting:
        _waitElapsedSeconds += _tickSeconds;
        if (_waitElapsedSeconds >= _waitSeconds) {
          _state = const FishingBiteState(
            phase: FishingBitePhase.ready,
            elapsedSeconds: 0,
          );
        }
      case FishingBitePhase.ready:
        final elapsed = _state.elapsedSeconds + _tickSeconds;
        if (elapsed > _biteWindowSeconds) {
          _state = FishingBiteState(
            phase: FishingBitePhase.missed,
            elapsedSeconds: _biteWindowSeconds,
          );
        } else {
          _state = FishingBiteState(
            phase: FishingBitePhase.ready,
            elapsedSeconds: elapsed,
          );
        }
      case FishingBitePhase.missed:
      case FishingBitePhase.struck:
        break;
    }
    return _state;
  }

  /// Resolves the player's rod pull without knowing anything about the UI.
  FishingStrikeResult strike({required int difficulty}) {
    switch (_state.phase) {
      case FishingBitePhase.waiting:
        _state = const FishingBiteState(
          phase: FishingBitePhase.missed,
          elapsedSeconds: 0,
        );
        return const FishingStrikeResult.fail(
          FishingStrikeFailReason.tooEarly,
        );
      case FishingBitePhase.ready:
        final result = FishingStrikeRules.evaluate(
          biteElapsedSeconds: _state.elapsedSeconds,
          biteWindowSeconds: _biteWindowSeconds,
          difficulty: difficulty,
        );
        _state = FishingBiteState(
          phase: result.isSuccess
              ? FishingBitePhase.struck
              : FishingBitePhase.missed,
          elapsedSeconds: _state.elapsedSeconds,
        );
        return result;
      case FishingBitePhase.missed:
      case FishingBitePhase.struck:
        return const FishingStrikeResult.fail(
          FishingStrikeFailReason.tooLate,
        );
    }
  }
}
