import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

typedef PendingCatchSync = Future<void> Function();
typedef ConnectivityStatusChanged = void Function(bool isOnline);

/// Retries the local catch queue when the device regains a network route.
/// Connectivity is only a trigger; the sync callback remains authoritative.
class OfflineSyncCoordinator {
  OfflineSyncCoordinator({
    required Stream<List<ConnectivityResult>> connectivityChanges,
    required PendingCatchSync syncPending,
    ConnectivityStatusChanged? onOnlineChanged,
  })  : _connectivityChanges = connectivityChanges,
        _syncPending = syncPending,
        _onOnlineChanged = onOnlineChanged;

  final Stream<List<ConnectivityResult>> _connectivityChanges;
  final PendingCatchSync _syncPending;
  final ConnectivityStatusChanged? _onOnlineChanged;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _syncInFlight = false;

  void start() {
    if (_subscription != null) return;
    _subscription = _connectivityChanges.listen(_handleConnectivityChange);
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  Future<void> _handleConnectivityChange(
    List<ConnectivityResult> results,
  ) async {
    final isOnline = results.any((result) => result != ConnectivityResult.none);
    _onOnlineChanged?.call(isOnline);
    if (!isOnline || _syncInFlight) return;

    _syncInFlight = true;
    try {
      await _syncPending();
    } finally {
      _syncInFlight = false;
    }
  }
}
