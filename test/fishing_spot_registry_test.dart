import 'package:flutter_test/flutter_test.dart';

import 'package:fishergo/features/fishing_spots/application/nearby_spots_controller.dart';
import 'package:fishergo/features/fishing_spots/data/fishing_spot_registry.dart';
import 'package:fishergo/features/fishing_spots/domain/fishing_spot.dart';

void main() {
  test('bundled registry contains only active audited verified spots', () {
    final spots = loadBundledFishingSpotRegistry();

    expect(spots, isNotEmpty);
    expect(spots.every((spot) => spot.isActiveVerified), isTrue);
    expect(spots.every((spot) => spot.isPubliclyEligible), isTrue);
    expect(
      spots.every(
        (spot) =>
            spot.source.isNotEmpty &&
            spot.sourceReference.isNotEmpty &&
            spot.reviewer.isNotEmpty &&
            spot.reviewedAt.year >= 2026,
      ),
      isTrue,
    );
    expect(spots.any((spot) => spot.nameZh.contains('希爾頓')), isFalse);
  });

  test('bundled registry carries location-specific fish habitat weights', () {
    final byId = <String, FishingSpot>{
      for (final spot in loadBundledFishingSpotRegistry()) spot.id: spot,
    };

    expect(byId['P017']!.habitatTags, contains('tung-chung-runway'));
    expect(byId['P017']!.speciesWeights, containsPair('fish-103', 4.0));
    expect(byId['P048']!.habitatTags, contains('north-water'));
    expect(byId['P048']!.speciesWeights, containsPair('fish-109', 4.0));

    expect(byId['P045']!.habitatTags, contains('sam-mun-tsai-tai-po-inner'));
    expect(byId['P045']!.speciesWeights, containsPair('fish-063', 4.0));

    expect(byId['P051']!.habitatTags, contains('tsing-ma-waters'));
    expect(byId['P051']!.speciesWeights, containsPair('fish-073', 4.0));
    expect(byId['P051']!.speciesWeights, containsPair('fish-069', 4.0));

    expect(byId['P035']!.habitatTags, contains('east-water'));
    expect(byId['P035']!.speciesWeights, containsPair('fish-140', 4.0));
    expect(byId['P035']!.speciesWeights, containsPair('fish-101', 4.0));
  });

  test('remote empty registry is respected instead of falling back to fixtures',
      () async {
    final controller = NearbySpotsController(() async => const []);

    final nearby = await controller.loadNearby(
      latitude: 22.3819,
      longitude: 114.1874,
      radiusMeters: 500,
    );

    expect(nearby, isEmpty);
  });

  test('nearby controller returns zero spots outside the verified radius',
      () async {
    final controller = NearbySpotsController(() async => [
          FishingSpot(
            id: 'spot-a',
            nameZh: '測試碼頭',
            latitude: 22.3000,
            longitude: 114.1700,
            coordinatePrecisionMeters: 10,
            kind: FishingSpotKind.pier,
            status: FishingSpotVerificationStatus.verified,
            publicAccess: true,
            safetyNotes: 'test',
            source: 'test',
            sourceReference: 'test',
            reviewer: 'test',
            reviewedAt: DateTime(2026, 7, 18),
            active: true,
          ),
        ]);

    final nearby = await controller.loadNearby(
      latitude: 22.3100,
      longitude: 114.1800,
      radiusMeters: 500,
    );

    expect(nearby, isEmpty);
  });

  test('distance calculation is approximately correct for Hong Kong scale', () {
    final meters = distanceMeters(22.3000, 114.1700, 22.3045, 114.1700);

    expect(meters, closeTo(500, 8));
  });
}
