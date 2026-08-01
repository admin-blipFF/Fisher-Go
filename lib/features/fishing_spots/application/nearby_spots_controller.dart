import '../domain/fishing_spot.dart';

class NearbySpotsController {
  const NearbySpotsController(this._repository);

  final Future<List<FishingSpot>> Function() _repository;

  Future<List<FishingSpot>> loadNearby({
    required double latitude,
    required double longitude,
    required double radiusMeters,
  }) async {
    final spots = await _repository();
    return spots
        .where(
          (spot) => spot.isWithinRadius(
            centerLatitude: latitude,
            centerLongitude: longitude,
            radiusMeters: radiusMeters,
          ),
        )
        .toList(growable: false);
  }
}
