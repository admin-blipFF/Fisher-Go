import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/generate_hk_terrain_mvp.dart';

void main() {
  test('retains OSM building polygons and heights', () {
    final asset = buildTerrainAsset(
      sourceCsv: 'name,type,lat,lon\n',
      osmVectorCacheJson: '''{"features":[{
        "osmId":9001,"kind":"building","name":"Test Block",
        "heightMeters":24,"radiusMeters":35,
        "geometry":{"type":"polygon","coordinates":[
          [22.3818,114.1873],[22.3818,114.1875],[22.3820,114.1875],
          [22.3818,114.1873]]}}]}''',
    );
    final building = (asset['features'] as List<Map<String, Object>>)
        .singleWhere((feature) => feature['kind'] == 'building');
    expect(building['kind'], 'building');
    expect(building['heightMeters'], 24);
    expect((building['geometry'] as Map)['type'], 'polygon');
    expect(asset['attribution'], '© OpenStreetMap contributors');
  });

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
    final osmRoads = features.where(
      (feature) => feature['kind'] == 'road' && feature['osmId'] != null,
    );
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

  test('bundles cached OSM buildings for Sha Tin and the Central waterfront',
      () {
    final asset = buildTerrainAsset(
      sourceCsv: File(
        'data/hk_geo/hk_fishing_spots_master_all_geocoded_gov.csv',
      ).readAsStringSync(),
      osmVectorCacheJson:
          File('data/hk_geo/osm_vector_cache.json').readAsStringSync(),
      osmRoadCacheJson:
          File('data/hk_geo/osm_road_geometry_cache.json').readAsStringSync(),
    );
    final cache = jsonDecode(
      File('data/hk_geo/osm_vector_cache.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final cachedBuildings = (cache['features'] as List<dynamic>)
        .map((feature) => Map<String, dynamic>.from(feature as Map))
        .where((feature) => feature['kind'] == 'building')
        .toList();
    final bundledBuildings = (asset['features'] as List<Map<String, Object>>)
        .where((feature) => feature['kind'] == 'building')
        .map((feature) => Map<String, dynamic>.from(feature))
        .toList();
    const expectedBuildingOsmIds = {
      188704698,
      188704701,
      25589595,
      1483823682,
    };

    void expectClosedBuildingPolygons(
      Iterable<Map<String, dynamic>> buildings,
    ) {
      for (final building in buildings) {
        final geometry = building['geometry'] as Map<String, dynamic>;
        final coordinates = geometry['coordinates'] as List<dynamic>;

        expect(geometry['type'], 'polygon');
        expect(coordinates.length, greaterThanOrEqualTo(4));
        expect(coordinates.first, equals(coordinates.last));
      }
    }

    expect(
      cachedBuildings.map((feature) => feature['osmId']).toSet(),
      equals(expectedBuildingOsmIds),
    );
    expect(cachedBuildings, hasLength(expectedBuildingOsmIds.length));
    expect(
      bundledBuildings.map((feature) => feature['osmId']).toSet(),
      equals(expectedBuildingOsmIds),
    );
    expect(bundledBuildings, hasLength(expectedBuildingOsmIds.length));
    expectClosedBuildingPolygons(cachedBuildings);
    expectClosedBuildingPolygons(bundledBuildings);
    expect(
      bundledBuildings
          .where((feature) => feature['region'] == 'central-waterfront')
          .map((feature) => feature['heightMeters']),
      containsAll([415.8, 14]),
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
