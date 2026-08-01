import '../domain/fishing_spot.dart';
import '../../catches/data/hk_fishing_spots_geocoded_seed.dart';
import 'fishing_spot_habitat_profiles.dart';

final bundledFishingSpotReviewDate = DateTime.utc(2026, 7, 18);

List<FishingSpot> loadBundledFishingSpotRegistry() {
  return hkFishingSpotsGeocodedSeed
      .where((spot) => spot.type == 'pier')
      .map(
        (spot) => FishingSpot(
          id: spot.id,
          nameZh: spot.nameZh,
          nameEn: spot.nameEn,
          latitude: spot.latitude,
          longitude: spot.longitude,
          coordinatePrecisionMeters: spot.radiusMeters,
          kind: FishingSpotKind.pier,
          status: FishingSpotVerificationStatus.verified,
          publicAccess: true,
          safetyNotes:
              'Check local access, tides, weather, and fishing rules before use.',
          source: 'FisherGO geocoded spot seed',
          sourceReference:
              'lib/features/catches/data/hk_fishing_spots_geocoded_seed.dart',
          reviewer: 'fishergo-team',
          reviewedAt: bundledFishingSpotReviewDate,
          active: true,
          habitatTags: habitatProfileForSpot(spot.id)?.habitatTags ??
              const ['nearshore', 'pier'],
          speciesWeights:
              habitatProfileForSpot(spot.id)?.speciesWeights ?? const {},
          environment: 'coastal',
        ),
      )
      .toList(growable: false);
}
