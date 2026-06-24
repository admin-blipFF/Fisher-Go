import 'dart:io';

import 'package:fishergo/features/catches/data/catch_log_local_data_source.dart';
import 'package:fishergo/features/catches/data/real_catch_claim_service.dart';
import 'package:fishergo/features/fish/domain/fish_collection_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('fishergo_real_catch_');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('claim stores a real catch proof entry in pending queue', () async {
    final local = CatchLogLocalDataSource(
      boxName: 'real_catch_claim_test',
      itemsKey: 'items',
    );
    final service = RealCatchClaimService(localDataSource: local);

    final result = await service.claim(
      speciesId: 'fish-063',
      speciesName: '烏頭',
      caughtAt: DateTime.utc(2026, 6, 24, 8),
      photoPath: '/local/photo.jpg',
      latitude: 22.45,
      longitude: 114.18,
      recognitionConfidence: 0.82,
      recognizedSpeciesId: 'fish-063',
    );

    final pending = await local.loadPending();
    expect(pending, hasLength(1));
    expect(pending.single.id, result.entry.id);
    expect(pending.single.isRealCatchProof, true);
    expect(pending.single.photoPath, '/local/photo.jpg');
    expect(pending.single.speciesId, 'fish-063');
    expect(
      result.collectionEntry.status,
      FishDiscoveryStatus.verifiedRealCatch,
    );
    expect(result.collectionEntry.showsPhotoProofBadge, true);
  });

  test('claim rejects empty photo paths', () async {
    final local = CatchLogLocalDataSource(
      boxName: 'real_catch_claim_empty_photo_test',
      itemsKey: 'items',
    );
    final service = RealCatchClaimService(localDataSource: local);

    expect(
      () => service.claim(
        speciesId: 'fish-063',
        speciesName: '烏頭',
        caughtAt: DateTime.utc(2026, 6, 24, 8),
        photoPath: '   ',
      ),
      throwsArgumentError,
    );
  });
}
