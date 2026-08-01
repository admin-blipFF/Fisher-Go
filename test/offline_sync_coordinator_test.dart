import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fishergo/features/catches/data/offline_sync_coordinator.dart';

void main() {
  test('reconnect triggers one pending sync and offline does nothing',
      () async {
    final connectivity = StreamController<List<ConnectivityResult>>();
    var syncCalls = 0;
    final coordinator = OfflineSyncCoordinator(
      connectivityChanges: connectivity.stream,
      syncPending: () async => syncCalls += 1,
    )..start();

    connectivity.add(const [ConnectivityResult.none]);
    await Future<void>.delayed(Duration.zero);
    expect(syncCalls, 0);

    connectivity.add(const [ConnectivityResult.wifi]);
    await Future<void>.delayed(Duration.zero);
    expect(syncCalls, 1);

    await coordinator.dispose();
    await connectivity.close();
  });

  test('reconnect events do not overlap pending sync attempts', () async {
    final connectivity = StreamController<List<ConnectivityResult>>();
    final syncStarted = Completer<void>();
    final releaseSync = Completer<void>();
    var syncCalls = 0;
    final coordinator = OfflineSyncCoordinator(
      connectivityChanges: connectivity.stream,
      syncPending: () async {
        syncCalls += 1;
        syncStarted.complete();
        await releaseSync.future;
      },
    )..start();

    connectivity.add(const [ConnectivityResult.mobile]);
    await syncStarted.future;
    connectivity.add(const [ConnectivityResult.wifi]);
    await Future<void>.delayed(Duration.zero);
    expect(syncCalls, 1);

    releaseSync.complete();
    await Future<void>.delayed(Duration.zero);
    await coordinator.dispose();
    await connectivity.close();
  });

  test('reports online state changes to the owning screen', () async {
    final connectivity = StreamController<List<ConnectivityResult>>();
    final statuses = <bool>[];
    final coordinator = OfflineSyncCoordinator(
      connectivityChanges: connectivity.stream,
      onOnlineChanged: statuses.add,
      syncPending: () async {},
    )..start();

    connectivity.add(const [ConnectivityResult.none]);
    connectivity.add(const [ConnectivityResult.mobile]);
    await Future<void>.delayed(Duration.zero);

    expect(statuses, [false, true]);

    await coordinator.dispose();
    await connectivity.close();
  });
}
