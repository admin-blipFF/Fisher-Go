enum FishingStrikeFailReason { tooEarly, tooLate }

class FishingStrikeResult {
  const FishingStrikeResult._(this.isSuccess, this.reason);

  const FishingStrikeResult.success() : this._(true, null);

  const FishingStrikeResult.fail(FishingStrikeFailReason reason)
      : this._(false, reason);

  final bool isSuccess;
  final FishingStrikeFailReason? reason;
}

class FishingStrikeRules {
  const FishingStrikeRules._();

  static FishingStrikeResult evaluate({
    required double biteElapsedSeconds,
    required double biteWindowSeconds,
    required int difficulty,
  }) {
    if (biteElapsedSeconds < 0) {
      return const FishingStrikeResult.fail(FishingStrikeFailReason.tooEarly);
    }

    final safeDifficulty = difficulty.clamp(1, 5);
    final validWindowEnd =
        biteWindowSeconds * (1 - (safeDifficulty - 1) * 0.09);
    if (biteElapsedSeconds > validWindowEnd) {
      return const FishingStrikeResult.fail(FishingStrikeFailReason.tooLate);
    }

    return const FishingStrikeResult.success();
  }
}
