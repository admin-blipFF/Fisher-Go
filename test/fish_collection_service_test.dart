import 'package:flutter_test/flutter_test.dart';

import 'package:fishergo/features/fish/domain/fish_collection_service.dart';
import 'package:fishergo/features/fish/domain/fish_collection_status.dart';

void main() {
  test('game catches unlock full-color icon without photo proof badge', () {
    const entry = PlayerFishCollectionEntry(
      fishId: 'fish-001',
      status: FishDiscoveryStatus.gameCaught,
    );

    expect(entry.status.showsColorIcon, true);
    expect(entry.showsPhotoProofBadge, false);
  });

  test('verified real catch shows hook badge only when a photo is uploaded',
      () {
    const withoutPhoto = PlayerFishCollectionEntry(
      fishId: 'fish-001',
      status: FishDiscoveryStatus.verifiedRealCatch,
    );
    const withPhoto = PlayerFishCollectionEntry(
      fishId: 'fish-001',
      status: FishDiscoveryStatus.verifiedRealCatch,
      realCatchPhotoPath: '/tmp/verified.jpg',
    );

    expect(withoutPhoto.status.showsColorIcon, true);
    expect(withoutPhoto.showsPhotoProofBadge, false);
    expect(withPhoto.status.showsColorIcon, true);
    expect(withPhoto.showsPhotoProofBadge, true);
  });

  test('cloud game-caught IDs do not downgrade local verified catches', () {
    final merged = FishCollectionService.mergeCloudCaughtIdsForTest(
      {
        'fish-001': const PlayerFishCollectionEntry(
          fishId: 'fish-001',
          status: FishDiscoveryStatus.verifiedRealCatch,
          realCatchPhotoPath: '/tmp/verified.jpg',
          bestLengthCm: 42,
        ),
      },
      {'fish-001', 'fish-002'},
    );

    expect(merged['fish-001']?.status, FishDiscoveryStatus.verifiedRealCatch);
    expect(merged['fish-001']?.realCatchPhotoPath, '/tmp/verified.jpg');
    expect(merged['fish-001']?.bestLengthCm, 42);
    expect(merged['fish-002']?.status, FishDiscoveryStatus.gameCaught);
  });
}
