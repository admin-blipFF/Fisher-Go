import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:integration_test/integration_test.dart';

import 'package:fishergo/features/catches/data/catch_log_local_data_source.dart';
import 'package:fishergo/features/catches/data/catch_sync_service.dart';
import 'package:fishergo/features/catches/domain/catch_log_entry.dart';
import 'package:fishergo/features/catches/presentation/catch_log_screen.dart';

class _FakeCatchRemote implements CatchRemoteDataSource {
  final List<CatchLogEntry> uploaded = [];

  @override
  Future<void> uploadCatch({
    required String userId,
    required CatchLogEntry entry,
  }) async {
    uploaded.add(entry);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'offline catch queue remains visible and syncs after reconnect',
    (tester) async {
      const queueName = 'integration_offline_reconnect_queue';
      await Hive.initFlutter();
      await Hive.deleteBoxFromDisk(queueName);

      final localDataSource = CatchLogLocalDataSource(boxName: queueName);
      final entry = CatchLogEntry(
        id: 'offline-reconnect-entry',
        speciesId: 'fish-063',
        speciesName: '烏頭',
        caughtAt: DateTime(2026, 7, 19, 8),
        photoPath: '/tmp/offline-catch.jpg',
      );
      await localDataSource.addPending(entry);

      final connectivity =
          StreamController<List<ConnectivityResult>>.broadcast();
      final remote = _FakeCatchRemote();
      final syncService = CatchSyncService(
        remote: remote,
        isConfigured: () => true,
        currentUserId: () => 'integration-user',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CatchLogScreen(
            localDataSource: localDataSource,
            syncService: syncService,
            connectivityChanges: connectivity.stream,
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 2));

      expect(find.textContaining('待備份：'), findsOneWidget);

      connectivity.add(const [ConnectivityResult.none]);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('離線'), findsOneWidget);
      expect(find.textContaining('待備份：1 筆'), findsOneWidget);

      connectivity.add(const [ConnectivityResult.wifi]);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('已連線'), findsOneWidget);
      expect(find.textContaining('待備份：0 筆'), findsOneWidget);
      expect(
          remote.uploaded.map((item) => item.id), ['offline-reconnect-entry']);

      await tester.pumpWidget(const SizedBox.shrink());
      await connectivity.close();
      await Hive.deleteBoxFromDisk(queueName);
    },
  );
}
