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
    expect(building['provenance'], 'openStreetMap');
    expect((building['geometry'] as Map)['type'], 'polygon');
    expect(asset['attribution'], '© OpenStreetMap contributors');
  });

  test('does not relabel cache coordinates without OSM ids as OSM', () {
    final asset = buildTerrainAsset(
      sourceCsv: 'name,type,lat,lon\nCSV Game Island,island,22.3,114.1\n',
      osmVectorCacheJson: '''{"features":[{
        "kind":"water","name":"Cached Coastline Without ID",
        "radiusMeters":1,"geometry":{"type":"polygon","coordinates":[
          [22.30,114.00],[22.30,114.01],[22.31,114.01],[22.30,114.00]
        ]}}]}''',
      osmRoadCacheJson: '''{"features":[{
        "osmId":7001,"kind":"road","name":"Cached Road",
        "radiusMeters":20,"geometry":{"type":"lineString","coordinates":[
          [22.30,114.00],[22.31,114.01]
        ]}}]}''',
    );
    final features = asset['features'] as List<Map<String, Object>>;
    final coastline = features.singleWhere(
      (feature) => feature['name'] == 'Cached Coastline Without ID',
    );
    final cachedRoad = features.singleWhere(
      (feature) => feature['name'] == 'Cached Road',
    );
    final csvIsland = features.singleWhere(
      (feature) => feature['name'] == 'CSV Game Island',
    );

    expect(coastline['osmId'], isNull);
    expect(coastline.containsKey('provenance'), isFalse);
    expect(cachedRoad['provenance'], 'openStreetMap');
    expect(
      features.any((feature) => feature['name'] == '維多利亞港海面'),
      isFalse,
    );
    expect(csvIsland.containsKey('provenance'), isFalse);
  });

  test('preserves stitched coastline provenance and hydro attribution', () {
    final asset = buildTerrainAsset(
      sourceCsv: 'name,type,lat,lon\n',
      osmHydroCacheJson: '''{"features":[{
        "osmId":-9000001,"sourceOsmIds":[101,102,103],
        "provenance":"openStreetMap","kind":"land","name":"",
        "radiusMeters":1,"geometry":{"type":"polygon","coordinates":[
          [22.30,114.00],[22.30,114.01],[22.31,114.01],[22.30,114.00]
        ]}}]}''',
    );
    final land = (asset['features'] as List<Map<String, Object>>)
        .singleWhere((feature) => feature['osmId'] == -9000001);

    expect(land['sourceOsmIds'], [101, 102, 103]);
    expect(asset['attribution'], '© OpenStreetMap contributors');
    expect(asset['license'], 'ODbL-1.0');
  });

  test('omits malformed OSM building polygons', () {
    final asset = buildTerrainAsset(
      sourceCsv: 'name,type,lat,lon\n',
      osmVectorCacheJson: '''{"features":[
        {"osmId":9001,"kind":"building","name":"Open Block",
        "radiusMeters":35,"geometry":{"type":"polygon","coordinates":[
          [22.3818,114.1873],[22.3818,114.1875],
          [22.3820,114.1875],[22.3820,114.1873]]}},
        {"osmId":9002,"kind":"building","name":"Triangle Block",
        "radiusMeters":35,"geometry":{"type":"polygon","coordinates":[
          [22.3818,114.1873],[22.3818,114.1875],
          [22.3818,114.1873]]}}
      ]}''',
    );

    expect(
      (asset['features'] as List<Map<String, Object>>)
          .where((feature) => feature['kind'] == 'building'),
      isEmpty,
    );
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
    expect(names, containsAll(['簡化汲水門水域', '簡化青馬主幹道']));

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
      containsAll(['motorway', 'trunk', 'primary', 'secondary']),
    );
    expect(
      roadClasses.intersection({'tertiary', 'local', 'service', 'footway'}),
      isEmpty,
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

  test('bundles exact current OSM coastline ways at Central Star Ferry', () {
    final cache = jsonDecode(
      File('data/hk_geo/osm_vector_cache.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final generated = buildTerrainAsset(
      sourceCsv: File(
        'data/hk_geo/hk_fishing_spots_master_all_geocoded_gov.csv',
      ).readAsStringSync(),
      osmVectorCacheJson: jsonEncode(cache),
      osmRoadCacheJson:
          File('data/hk_geo/osm_road_geometry_cache.json').readAsStringSync(),
      osmHydroCacheJson:
          File('data/hk_geo/osm_hydro_geometry_cache.json').readAsStringSync(),
    );
    final cachedCoastline = (cache['features'] as List<dynamic>)
        .map((feature) => Map<String, dynamic>.from(feature as Map))
        .where((feature) =>
            feature['region'] == 'central-waterfront' &&
            feature['kind'] == 'shore')
        .toList();
    final bundledCoastline =
        (generated['features'] as List<Map<String, Object>>)
            .where((feature) =>
                feature['region'] == 'central-waterfront' &&
                feature['kind'] == 'shore')
            .map((feature) => Map<String, dynamic>.from(feature))
            .toList();
    final snapshot = cache['osmCoastlineImport'] as Map<String, dynamic>;

    expect(
      (generated['features'] as List<Map<String, Object>>)
          .any((feature) => feature['name'] == '維多利亞港海面'),
      isFalse,
    );
    expect(cachedCoastline.map((feature) => feature['osmId']).toSet(),
        {276452994, 1114868225});
    expect(cachedCoastline.map((feature) => feature['osmVersion']).toSet(),
        {56, 7});
    expect(bundledCoastline, hasLength(2));
    for (final cached in cachedCoastline) {
      final bundled = bundledCoastline.singleWhere(
        (feature) => feature['osmId'] == cached['osmId'],
      );
      final geometry = cached['geometry'] as Map<String, dynamic>;
      final coordinates = geometry['coordinates'] as List<dynamic>;
      final nodeIds = cached['osmNodeIds'] as List<dynamic>;

      expect(geometry['type'], 'lineString');
      expect(coordinates, hasLength(nodeIds.length));
      expect(coordinates.first, isNot(equals(coordinates.last)));
      expect(bundled['provenance'], 'openStreetMap');
      expect(bundled['osmVersion'], cached['osmVersion']);
      expect(bundled['osmNodeIds'], nodeIds);
      expect((bundled['geometry'] as Map)['coordinates'], coordinates);
    }
    expect(
      snapshot['queryUrl'],
      'https://api.openstreetmap.org/api/0.6/map?bbox='
      '114.1580,22.2838,114.1630,22.2875',
    );
    expect(snapshot['retrievedAt'], '2026-07-13T03:20:26.5709106Z');
    expect(snapshot['attribution'], '© OpenStreetMap contributors');
    expect(
      (generated['osmCoastlineImport'] as Map)['ways'],
      snapshot['ways'],
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
      osmHydroCacheJson:
          File('data/hk_geo/osm_hydro_geometry_cache.json').readAsStringSync(),
    );
    final current = jsonDecode(
      File('assets/maps/hk_terrain_mvp.json').readAsStringSync(),
    ) as Map<String, dynamic>;

    expect(current, generated);
  });

  test('bundles Victoria Harbour and major river surface geometry', () {
    final generated = buildTerrainAsset(
      sourceCsv: File(
        'data/hk_geo/hk_fishing_spots_master_all_geocoded_gov.csv',
      ).readAsStringSync(),
      osmVectorCacheJson:
          File('data/hk_geo/osm_vector_cache.json').readAsStringSync(),
      osmRoadCacheJson:
          File('data/hk_geo/osm_road_geometry_cache.json').readAsStringSync(),
    );
    final water = (generated['features'] as List)
        .whereType<Map<String, Object>>()
        .where((feature) => feature['kind'] == 'water')
        .toList();
    final names = water.map((feature) => feature['name']).toSet();

    expect(names, contains('維多利亞港'));
    expect(names, contains('城門河'));
    expect(names, contains('屯門河'));
    expect(
      water.any(
        (feature) =>
            feature['name'] == '維多利亞港' &&
            (feature['geometry'] as Map)['type'] == 'polygon',
      ),
      isTrue,
    );
  });
}
