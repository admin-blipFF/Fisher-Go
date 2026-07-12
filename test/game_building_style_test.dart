import 'package:fishergo/features/game_home/domain/game_building_style.dart';
import 'package:fishergo/features/game_home/domain/terrain_data_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test('building style bounds perspective extrusion', () {
    const feature = TerrainVectorFeature(
      kind: TerrainKind.building,
      name: 'Block',
      points: [
        LatLng(22.0, 114.0),
        LatLng(22.0, 114.001),
        LatLng(22.001, 114.001),
        LatLng(22.0, 114.0),
      ],
      isClosed: true,
      heightMeters: 30,
    );
    final far = GameBuildingStyle.forFeature(
      feature,
      depthScale: 0.4,
      simplified: false,
    );
    final near = GameBuildingStyle.forFeature(
      feature,
      depthScale: 1.6,
      simplified: false,
    );

    expect(far.extrusionPixels, greaterThanOrEqualTo(3));
    expect(near.extrusionPixels, lessThanOrEqualTo(15));
    expect(near.extrusionPixels, greaterThan(far.extrusionPixels));
  });
}
