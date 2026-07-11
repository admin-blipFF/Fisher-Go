import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/generate_hk_terrain_mvp.dart';

void main() {
  test('builds terrain asset from geocoded Hong Kong source data', () {
    final asset = buildTerrainAsset(
      sourceCsv: File(
        'data/hk_geo/hk_fishing_spots_master_all_geocoded_gov.csv',
      ).readAsStringSync(),
      osmVectorCacheJson:
          File('data/hk_geo/osm_vector_cache.json').readAsStringSync(),
      osmRoadCacheJson:
          File('data/hk_geo/osm_road_geometry_cache.json').readAsStringSync(),
    );
    final features = asset['features'] as List<Map<String, Object>>;
    final names = features.map((feature) => feature['name']).toSet();
    final kinds = features.map((feature) => feature['kind']).toSet();
    final geometryFeatures =
        features.where((feature) => feature.containsKey('geometry')).toList();

    expect(features.length, greaterThan(70));
    expect(
        kinds, containsAll(['water', 'land', 'road', 'pier', 'fishingNode']));
    expect(names, containsAll(['青馬大橋', '三門仔村碼頭', '長洲公眾碼頭', '跑道尾立魚位']));
    expect(geometryFeatures.length, greaterThanOrEqualTo(6));
    expect(names, containsAll(['OSM 汲水門水域', 'OSM 青馬主幹道']));

    final roadCache = jsonDecode(
      File('data/hk_geo/osm_road_geometry_cache.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final cachedRoads = roadCache['features'] as List<dynamic>;
    final osmRoads = features.where((feature) => feature['osmId'] != null);
    final roadClasses = osmRoads.map((feature) => feature['roadClass']).toSet();

    expect(osmRoads.length, cachedRoads.length);
    expect(osmRoads.map((feature) => feature['osmId']).toSet().length,
        cachedRoads.length);
    expect(
      roadClasses,
      containsAll(['primary', 'secondary', 'local', 'footway', 'cycleway']),
    );
    expect(osmRoads.any((feature) => feature['isBridge'] == true), isTrue);
    expect(
      asset['generatedFrom'],
      contains('data/hk_geo/osm_road_geometry_cache.json'),
    );
    expect(asset['license'], 'ODbL-1.0');
    expect(
      asset['licenseUrl'],
      'https://www.openstreetmap.org/copyright',
    );
  });

  test('current bundled terrain asset matches generator output', () {
    final generated = buildTerrainAsset(
      sourceCsv: File(
        'data/hk_geo/hk_fishing_spots_master_all_geocoded_gov.csv',
      ).readAsStringSync(),
      osmVectorCacheJson:
          File('data/hk_geo/osm_vector_cache.json').readAsStringSync(),
      osmRoadCacheJson:
          File('data/hk_geo/osm_road_geometry_cache.json').readAsStringSync(),
    );
    final current = jsonDecode(
      File('assets/maps/hk_terrain_mvp.json').readAsStringSync(),
    ) as Map<String, dynamic>;

    expect(current, generated);
  });
}
