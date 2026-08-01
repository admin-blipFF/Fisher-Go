import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('identity dialog serializes explicit actions with auth callbacks', () {
    final source = File(
      'lib/features/game_home/presentation/game_home_screen.dart',
    ).readAsStringSync();

    expect(source, contains('_identityDialogActionInFlight'));
    expect(source, contains('_identityDialogResultSent'));
    expect(source, contains('_identityDialogOpen'));
    expect(source, contains('!_identityDialogActionInFlight'));
    expect(source, contains('!_identityDialogResultSent'));
    expect(source, contains('_identityDialogResultSent = true;'));
    expect(source, contains('_startupGateInFlight'));
    expect(source, contains('_tutorialDialogOpen'));

    final identityGuard = source.indexOf('if (_identityDialogOpen)');
    final startupGateCall = source.indexOf('unawaited(_runStartupGate())');
    expect(identityGuard, greaterThanOrEqualTo(0));
    expect(startupGateCall, greaterThan(identityGuard));
    expect(
      source.substring(identityGuard, startupGateCall),
      contains('return;'),
    );

    final startupGuard = source.indexOf(
      'if (!mounted || _startupGateInFlight) return;',
    );
    final startupResolve = source.indexOf(
      'var state = await _resolveStartupState();',
    );
    expect(startupGuard, greaterThanOrEqualTo(0));
    expect(startupResolve, greaterThan(startupGuard));
    expect(source, contains('_startupGateInFlight = true;'));
    expect(source, contains('_startupGateInFlight = false;'));
    expect(source, contains('await _showTutorialOverlay();'));
  });
}
