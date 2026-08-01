import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('catch log minigame uses the bite-first collection rule', () {
    final source = File(
      'lib/features/catches/presentation/catch_log_screen.dart',
    ).readAsStringSync();

    expect(source, contains('浮標急震'));
    expect(source, contains('抽竿'));
    expect(source, contains('成功會解鎖全彩圖示'));
    expect(source, isNot(contains('成功會解鎖灰章')));
  });

  test('cancelling the catch dialog does not consume the lure', () {
    final source = File(
      'lib/features/catches/presentation/catch_log_screen.dart',
    ).readAsStringSync();

    expect(
      source,
      contains('final result = await showDialog<_FishingMinigameResult>'),
    );
    expect(source, contains('if (result == null) return;'));
    expect(source, contains('Navigator.of(context).pop();'));
    expect(
      source.indexOf('if (result == null) return;'),
      lessThan(source.indexOf('consumeConsumable')),
    );
  });

  test('GameHome result reveals the full-color fish artwork after a catch', () {
    final source = File(
      'lib/features/game_home/presentation/game_home_screen.dart',
    ).readAsStringSync();

    expect(
      source,
      contains('Image.asset(\n                    _caughtFish!.iconAsset,'),
    );
    expect(
      source,
      contains('if (won && _caughtFish != null && _showResultDetails)'),
    );
  });

  test('GameHome delegates bite timing to the tested domain controller', () {
    final source = File(
      'lib/features/game_home/presentation/game_home_screen.dart',
    ).readAsStringSync();

    expect(source, contains('FishingBiteController'));
    expect(source, contains('_biteController'));
    expect(source, contains('controller.advance()'));
  });

  test('both minigame surfaces announce bite state and action semantics', () {
    final gameHomeSource = File(
      'lib/features/game_home/presentation/game_home_screen.dart',
    ).readAsStringSync();
    final catchLogSource = File(
      'lib/features/catches/presentation/catch_log_screen.dart',
    ).readAsStringSync();

    expect(gameHomeSource, contains('liveRegion: true'));
    expect(gameHomeSource, contains('label: isBiting ? \'抽竿，立即抽竿\''));
    expect(gameHomeSource, contains('excludeSemantics: true'));
    expect(catchLogSource, contains('liveRegion: true'));
    expect(catchLogSource, contains('label: actionLabel'));
    expect(catchLogSource, contains('excludeSemantics: true'));
  });

  test('pull gesture callbacks ignore late events after the overlay closes',
      () {
    final source = File(
      'lib/features/game_home/presentation/game_home_screen.dart',
    ).readAsStringSync();

    expect(
      source,
      contains('void _onPullStart() {\n    if (!mounted) return;'),
    );
    expect(
      source,
      contains('void _onPullEnd() {\n    if (!mounted) return;'),
    );
  });
}
