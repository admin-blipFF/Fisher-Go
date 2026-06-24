import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:fishergo/features/catches/data/catch_log_local_data_source.dart';
import 'package:fishergo/features/catches/domain/catch_log_entry.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('fishergo_hive_test_');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    if (Hive.isBoxOpen('test_catch_queue')) {
      final box = Hive.box<dynamic>('test_catch_queue');
      await box.clear();
      await box.close();
    }
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('persists pending catch entry in hive queue', () async {
    final dataSource = CatchLogLocalDataSource(boxName: 'test_catch_queue');

    final entry = CatchLogEntry(
      id: 'entry-1',
      speciesId: 'sample-yellowfin-seabream',
      speciesName: '黃腳鱲',
      caughtAt: DateTime(2026, 5, 31, 7, 30),
      lengthCm: 32.5,
      weightKg: 1.2,
      notes: '碼頭慢抽',
      photoPath: '/tmp/fish.jpg',
      latitude: 22.281,
      longitude: 114.158,
      syncStatus: CatchSyncStatus.pending,
    );

    await dataSource.addPending(entry);

    final freshDataSource =
        CatchLogLocalDataSource(boxName: 'test_catch_queue');
    final loaded = await freshDataSource.loadPending();

    expect(loaded.length, 1);
    expect(loaded.first.id, 'entry-1');
    expect(loaded.first.speciesName, '黃腳鱲');
    expect(loaded.first.lengthCm, 32.5);
    expect(loaded.first.weightKg, 1.2);
    expect(loaded.first.notes, '碼頭慢抽');
    expect(loaded.first.photoPath, '/tmp/fish.jpg');
    expect(loaded.first.latitude, 22.281);
    expect(loaded.first.longitude, 114.158);
    expect(loaded.first.syncStatus, CatchSyncStatus.pending);
  });

  test('persists real catch proof metadata in hive queue', () async {
    final entry = CatchLogEntry(
      speciesId: 'fish-063',
      speciesName: '烏頭',
      caughtAt: DateTime.utc(2026, 6, 24, 8),
      photoPath: '/local/photo.jpg',
      latitude: 22.45,
      longitude: 114.18,
      isRealCatchProof: true,
      recognitionConfidence: 0.82,
      recognizedSpeciesId: 'fish-063',
      verifiedAt: DateTime.utc(2026, 6, 24, 8, 1),
    );

    final restored = CatchLogEntry.fromMap(entry.toMap());

    expect(restored.isRealCatchProof, true);
    expect(restored.recognitionConfidence, 0.82);
    expect(restored.recognizedSpeciesId, 'fish-063');
    expect(restored.verifiedAt, DateTime.utc(2026, 6, 24, 8, 1));
  });
}
