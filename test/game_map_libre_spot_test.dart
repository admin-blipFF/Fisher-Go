import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre/maplibre.dart';

import 'package:fishergo/features/map/domain/game_map_spot.dart';

void main() {
  test('game map spot preserves FisherGO coordinates for MapLibre', () {
    const spot = GameMapSpot(
      id: 'spot-1',
      name: '沙田河道',
      latitude: 22.3819,
      longitude: 114.1874,
    );

    expect(spot.point, const Geographic(lon: 114.1874, lat: 22.3819));
    expect(spot.displayLabel, '沙田河道');
  });
}
