import 'package:fishergo/features/map/application/map_cache_policy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre/maplibre.dart';

void main() {
  test('map cache policy stays bounded for a mobile gameplay session', () {
    expect(MapCachePolicy.offlineTileLimit, 4000);
    expect(MapCachePolicy.ambientCacheBytes, 64 * 1024 * 1024);
    expect(MapCachePolicy.packDatabaseAutomatically, isTrue);
    expect(MapCachePolicy.warmupRadiusMeters, 500);
    expect(MapCachePolicy.warmupPixelDensity, 1);
    expect(MapCachePolicy.warmupStyleUrl, contains('openfreemap.org/styles'));
  });

  test('warm-up bounds cover a 500m GPS gameplay area', () {
    const center = Geographic(lon: 114.1874, lat: 22.3819);
    final bounds = MapCachePolicy.warmupBoundsFor(center);

    expect(bounds.latitudeNorth - center.lat, closeTo(0.00449, 0.00001));
    expect(bounds.latitudeSouth, closeTo(22.3774, 0.00001));
    expect(bounds.longitudeEast - center.lon, closeTo(0.00486, 0.00001));
    expect(MapCachePolicy.warmupMinZoom, 14);
    expect(MapCachePolicy.warmupMaxZoom, 16);
    expect(MapCachePolicy.warmupGridKey(center), '11191:57094');
  });
}
