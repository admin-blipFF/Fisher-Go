/// The identity that owns local and cloud progress at startup.
enum PlayerIdentityState {
  signedOut,
  guestLocal,
  anonymousCloud,
  authenticated,
  tutorialPending,
  ready,
}
