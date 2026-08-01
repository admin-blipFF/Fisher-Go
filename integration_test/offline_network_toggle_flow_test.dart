import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:integration_test/integration_test.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'package:fishergo/features/catches/data/catch_log_local_data_source.dart';
import 'package:fishergo/features/catches/data/catch_sync_service.dart';
import 'package:fishergo/features/catches/domain/catch_log_entry.dart';
import 'package:fishergo/features/catches/presentation/catch_log_screen.dart';

class _FakeCatchRemote implements CatchRemoteDataSource {
  final List<CatchLogEntry> uploaded = [];
  bool allowUploads = false;

  @override
  Future<void> uploadCatch({
    required String userId,
    required CatchLogEntry entry,
  }) async {
    if (!allowUploads) {
      throw StateError('network is intentionally unavailable');
    }
    uploaded.add(entry);
  }
}

Future<void> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  required Duration timeout,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure(
    'Timed out waiting for ${finder.describeMatch(Plurality.many)}.',
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'real Android connectivity toggles offline queue and reconnect sync',
    (tester) async {
      const queueName = 'integration_network_toggle_queue';
      await Hive.initFlutter();
      await Hive.deleteBoxFromDisk(queueName);

      final localDataSource = CatchLogLocalDataSource(boxName: queueName);
      final entry = CatchLogEntry(
        id: 'network-toggle-entry',
        speciesId: 'fish-063',
        speciesName: '烏頭',
        caughtAt: DateTime(2026, 8, 1, 8),
        photoPath: '/tmp/network-toggle-catch.jpg',
      );
      await localDataSource.addPending(entry);

      final remote = _FakeCatchRemote();
      final connectivity = Connectivity();
      final connectivityEvents = <List<ConnectivityResult>>[];
      final initialConnectivity = await connectivity.checkConnectivity();
      connectivityEvents.add(initialConnectivity);
      var queueReady = false;
      final restored = Completer<void>();
      final connectivitySubscription =
          connectivity.onConnectivityChanged.listen((results) {
        connectivityEvents.add(results);
        // The API 35 emulator may report mobile while radios are disabled.
        // Treat the first subsequent Wi-Fi event as the real restore edge.
        if (queueReady &&
            results.contains(ConnectivityResult.wifi) &&
            !restored.isCompleted) {
          remote.allowUploads = true;
          restored.complete();
        }
      });
      final syncService = CatchSyncService(
        remote: remote,
        isConfigured: () => true,
        currentUserId: () => 'integration-network-user',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CatchLogScreen(
            localDataSource: localDataSource,
            syncService: syncService,
          ),
        ),
      );

      await _pumpUntil(
        tester,
        find.textContaining('待備份：1 筆'),
        timeout: const Duration(seconds: 10),
      );
      expect(find.textContaining('待備份：1 筆'), findsOneWidget);
      queueReady = true;
      await restored.future.timeout(const Duration(seconds: 45));
      expect(
        connectivityEvents,
        contains(contains(ConnectivityResult.wifi)),
      );
      await _pumpUntil(
        tester,
        find.textContaining('待備份：0 筆'),
        timeout: const Duration(seconds: 10),
      );
      expect(remote.uploaded.map((item) => item.id), ['network-toggle-entry']);

      await tester.pumpWidget(const SizedBox.shrink());
      await connectivitySubscription.cancel();
      await Hive.deleteBoxFromDisk(queueName);
    },
  );
}
