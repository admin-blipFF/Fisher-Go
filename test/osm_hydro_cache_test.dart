import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../tool/update_osm_hydro_cache.dart';

void main() {
  String overpass(List<Map<String, Object>> elements) => jsonEncode({
        'elements': elements,
      });

  Map<String, Object> coastlineWay(
    int id,
    List<(double, double)> points,
  ) =>
      {
        'type': 'way',
        'id': id,
        'tags': {'natural': 'coastline'},
        'geometry': [
          for (final point in points) {'lat': point.$1, 'lon': point.$2},
        ],
      };

  test('closed OSM coastline becomes a fillable land polygon', () {
    final cache = buildHydroCacheFromOverpassJson(
      coastlineJson: overpass([
        coastlineWay(101, const [
          (22.34, 114.05),
          (22.35, 114.05),
          (22.35, 114.06),
          (22.34, 114.05),
        ]),
      ]),
      inlandWaterJson: overpass(const []),
    );
    final feature = (cache['features'] as List).single as Map;

    expect(feature['kind'], 'land');
    expect(feature['osmId'], 101);
    expect((feature['geometry'] as Map)['type'], 'polygon');
    final coordinates = (feature['geometry'] as Map)['coordinates'] as List;
    expect(coordinates.first, coordinates.last);
  });

  test('connected OSM coastline ways are stitched into one land polygon', () {
    final cache = buildHydroCacheFromOverpassJson(
      coastlineJson: overpass([
        coastlineWay(201, const [
          (22.30, 114.10),
          (22.31, 114.11),
        ]),
        coastlineWay(202, const [
          (22.31, 114.11),
          (22.29, 114.12),
        ]),
        coastlineWay(203, const [
          (22.29, 114.12),
          (22.30, 114.10),
        ]),
      ]),
      inlandWaterJson: overpass(const []),
    );
    final features = cache['features'] as List;
    final land =
        features.where((feature) => (feature as Map)['kind'] == 'land');

    expect(land, hasLength(1));
    expect(features.where((feature) => (feature as Map)['kind'] == 'shore'),
        isEmpty);
    final polygon = ((land.single as Map)['geometry'] as Map);
    expect(polygon['type'], 'polygon');
    final coordinates = polygon['coordinates'] as List;
    expect(coordinates.first, coordinates.last);
    expect(coordinates.length, greaterThanOrEqualTo(4));
  });

  test('unclosed coastline remains a shore line', () {
    final cache = buildHydroCacheFromOverpassJson(
      coastlineJson: overpass([
        coastlineWay(301, const [
          (22.30, 114.10),
          (22.31, 114.11),
        ]),
      ]),
      inlandWaterJson: overpass(const []),
    );
    final feature = (cache['features'] as List).single as Map;

    expect(feature['kind'], 'shore');
    expect((feature['geometry'] as Map)['type'], 'lineString');
  });

  test('does not reverse coastline ways to fabricate a land polygon', () {
    final cache = buildHydroCacheFromOverpassJson(
      coastlineJson: overpass([
        coastlineWay(401, const [
          (22.30, 114.10),
          (22.31, 114.11),
        ]),
        coastlineWay(402, const [
          (22.29, 114.12),
          (22.31, 114.11),
        ]),
        coastlineWay(403, const [
          (22.29, 114.12),
          (22.30, 114.10),
        ]),
      ]),
      inlandWaterJson: overpass(const []),
    );
    final features = cache['features'] as List;

    expect(
      features.where((feature) => (feature as Map)['kind'] == 'land'),
      isEmpty,
    );
    expect(
      features.where((feature) => (feature as Map)['kind'] == 'shore'),
      hasLength(3),
    );
  });
}
