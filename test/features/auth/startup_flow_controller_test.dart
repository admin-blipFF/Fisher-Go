import 'package:flutter_test/flutter_test.dart';

import 'package:fishergo/features/auth/application/startup_flow_controller.dart';
import 'package:fishergo/features/auth/domain/player_identity_state.dart';

void main() {
  const controller = StartupFlowController();

  test('fresh player must choose an identity before tutorial', () {
    expect(
      controller.resolve(const StartupFlowSnapshot()),
      PlayerIdentityState.signedOut,
    );
  });

  test('local guest is distinct from anonymous cloud identity', () {
    expect(
      controller.resolve(const StartupFlowSnapshot(guestModeSelected: true)),
      PlayerIdentityState.guestLocal,
    );
    expect(
      controller.resolve(
        const StartupFlowSnapshot(hasSession: true, sessionIsAnonymous: true),
      ),
      PlayerIdentityState.anonymousCloud,
    );
  });

  test('identity with incomplete tutorial enters tutorial pending', () {
    expect(
      controller.nextStep(
        const StartupFlowSnapshot(
          hasSession: true,
          sessionIsAnonymous: false,
        ),
      ),
      PlayerIdentityState.tutorialPending,
    );
  });

  test('completed tutorial enters ready state', () {
    expect(
      controller.nextStep(
        const StartupFlowSnapshot(
          guestModeSelected: true,
          tutorialCompleted: true,
        ),
      ),
      PlayerIdentityState.ready,
    );
  });
}
