import '../domain/player_identity_state.dart';

class StartupFlowSnapshot {
  const StartupFlowSnapshot({
    this.hasSession = false,
    this.sessionIsAnonymous = false,
    this.guestModeSelected = false,
    this.tutorialCompleted = false,
  });

  final bool hasSession;
  final bool sessionIsAnonymous;
  final bool guestModeSelected;
  final bool tutorialCompleted;
}

/// Pure startup state transitions so UI code does not infer identity from
/// `currentUser != null` alone.
class StartupFlowController {
  const StartupFlowController();

  PlayerIdentityState resolve(StartupFlowSnapshot snapshot) {
    if (snapshot.hasSession) {
      return snapshot.sessionIsAnonymous
          ? PlayerIdentityState.anonymousCloud
          : PlayerIdentityState.authenticated;
    }
    if (snapshot.guestModeSelected) return PlayerIdentityState.guestLocal;
    return PlayerIdentityState.signedOut;
  }

  PlayerIdentityState nextStep(StartupFlowSnapshot snapshot) {
    final identity = resolve(snapshot);
    if (identity == PlayerIdentityState.signedOut) return identity;
    return snapshot.tutorialCompleted
        ? PlayerIdentityState.ready
        : PlayerIdentityState.tutorialPending;
  }
}
