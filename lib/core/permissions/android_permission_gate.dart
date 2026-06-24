/// Serializes Android runtime permission prompts.
///
/// Android rejects overlapping permission requests with
/// "Can request only one set of permissions at a time". This gate keeps
/// independent screens from opening permission prompts concurrently.
class AndroidPermissionGate {
  AndroidPermissionGate._();

  static Future<void> _tail = Future<void>.value();

  static Future<T> run<T>(Future<T> Function() action) {
    final next = _tail.then((_) => action());
    _tail = next.then<void>((_) {}, onError: (_) {});
    return next;
  }
}
