import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('GameHome requests location after identity and tutorial gates', () {
    final source = File(
      'lib/features/game_home/presentation/game_home_screen.dart',
    ).readAsStringSync();

    expect(source, contains('onTap: _loadPlayerLocation'));
    expect(source, contains('unawaited(_loadPlayerLocation());'));
    expect(
        source, contains('if (state == PlayerIdentityState.tutorialPending)'));
    expect(source, contains('return;'));
    expect(source, contains('LocationAccessService().ensureReady()'));
    expect(source, contains('LocationAccessState.serviceDisabled'));
    expect(source, contains('LocationAccessState.permissionDeniedForever'));
  });
}
