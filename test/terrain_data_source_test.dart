import 'dart:io';

import 'package:fishergo/features/game_home/domain/terrain_data_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test('terrain polygon containment distinguishes land and water positions',
      () {
    const polygon = [
      LatLng(22.38, 114.18),
      LatLng(22.38, 114.20),
      LatLng(22.40, 114.20),
      LatLng(22.40, 114.18),
    ];

    expect(
      terrainPolygonContains(const LatLng(22.39, 114.19), polygon),
      isTrue,
    );
    expect(
      terrainPolygonContains(const LatLng(22.41, 114.19), polygon),
      isFalse,
    );
  });

  group('LocalTerrainDataSource', () {
    test('builds a deterministic grid with all gameplay terrain types', () {
      const source = LocalTerrainDataSource();
      final tiles = source.buildTiles(
        playerLatLng: const LatLng(22.36, 114.135),
        rows: 15,
        cols: 11,
      );

      expect(tiles, hasLength(165));
      expect(
        tiles.map((tile) => tile.kind).toSet(),
        containsAll({
          TerrainKind.water,
          TerrainKind.shore,
          TerrainKind.land,
          TerrainKind.road,
          TerrainKind.pier,
          TerrainKind.fishingNode,
        }),
      );

      final sameTiles = source.buildTiles(
        playerLatLng: const LatLng(22.36, 114.135),
        rows: 15,
        cols: 11,
      );
      expect(sameTiles, tiles);
    });

    test('projects fishing spots into normalized game-map coordinates', () {
      const source = LocalTerrainDataSource();
      final points = source.projectFishingNodes([
        const TerrainFishingSpot(lat: 22.287, lng: 114.158),
        const TerrainFishingSpot(lat: 22.331, lng: 114.062),
      ]);

      expect(points, hasLength(2));
      for (final point in points) {
        expect(point.dx, inInclusiveRange(0.12, 0.88));
        expect(point.dy, inInclusiveRange(0.22, 0.82));
      }
      expect(points.first, isNot(points.last));
    });

    test('returns no fishing nodes when no visible spots are available', () {
      const source = LocalTerrainDataSource();
      final points = source.projectFishingNodes(const []);

      expect(points, isEmpty);
    });
  });

  group('GeoTerrainDataSource', () {
    test('expands the generated world grid to match a landscape viewport', () {
      final json = File('assets/maps/hk_terrain_mvp.json').readAsStringSync();
      final source = GeoTerrainDataSource(GeoTerrainDataset.fromJson(json));
      const player = LatLng(22.3517, 114.0743);
      const distance = Distance();

      final portrait = source.buildTiles(
        playerLatLng: player,
        rows: 29,
        cols: 15,
      );
      final landscape = source.buildTiles(
        playerLatLng: player,
        rows: 29,
        cols: 51,
      );
      double eastWestSpan(List<TerrainTile> tiles) {
        final west = tiles.reduce((a, b) =>
            a.centerLatLng.longitude < b.centerLatLng.longitude ? a : b);
        final east = tiles.reduce((a, b) =>
            a.centerLatLng.longitude > b.centerLatLng.longitude ? a : b);
        return distance.as(
          LengthUnit.Meter,
          west.centerLatLng,
          east.centerLatLng,
        );
      }

      expect(eastWestSpan(portrait), closeTo(500, 70));
      expect(eastWestSpan(landscape), closeTo(1785, 120));
    });

    test('parses bundled Hong Kong terrain vector data', () {
      final json = File('assets/maps/hk_terrain_mvp.json').readAsStringSync();
      final dataset = GeoTerrainDataset.fromJson(json);

      expect(dataset.features, isNotEmpty);
      expect(
        dataset.features.map((feature) => feature.kind).toSet(),
        containsAll({
          TerrainKind.water,
          TerrainKind.land,
          TerrainKind.road,
          TerrainKind.pier,
          TerrainKind.fishingNode,
        }),
      );
      expect(dataset.features.map((feature) => feature.name), contains('青馬大橋'));
    });

    test('production sampling identifies Sha Tin as land-dominant', () {
      final json = File('assets/maps/hk_terrain_mvp.json').readAsStringSync();
      final source = GeoTerrainDataSource(GeoTerrainDataset.fromJson(json));
      final tiles = source.buildTiles(
        playerLatLng: const LatLng(22.3819, 114.1874),
        rows: 11,
        cols: 9,
      );
      final landCount =
          tiles.where((tile) => tile.kind == TerrainKind.land).length;
      final waterCount =
          tiles.where((tile) => tile.kind == TerrainKind.water).length;

      expect(landCount, greaterThan(waterCount));
    });

    test('classifies Tsing Ma area from real terrain features', () {
      final json = File('assets/maps/hk_terrain_mvp.json').readAsStringSync();
      final source = GeoTerrainDataSource(GeoTerrainDataset.fromJson(json));

      final tiles = source.buildTiles(
        playerLatLng: const LatLng(22.3517, 114.0743),
        rows: 15,
        cols: 15,
      );
      final kinds = tiles.map((tile) => tile.kind).toSet();

      expect(kinds, contains(TerrainKind.water));
      expect(kinds, contains(TerrainKind.land));
      expect(kinds, contains(TerrainKind.road));
      expect(kinds, contains(TerrainKind.fishingNode));
    });

    test('classifies major Hong Kong sea areas from real terrain features', () {
      final json = File('assets/maps/hk_terrain_mvp.json').readAsStringSync();
      final source = GeoTerrainDataSource(GeoTerrainDataset.fromJson(json));

      for (final seaPoint in const [
        LatLng(22.298, 114.17), // Victoria Harbour open water.
        LatLng(22.3332, 114.1112), // Rambler Channel.
        LatLng(22.4489, 114.2261), // Tolo Harbour.
      ]) {
        final tiles = source.buildTiles(
          playerLatLng: seaPoint,
          rows: 7,
          cols: 7,
        );
        final centerTile = tiles.singleWhere(
          (tile) => tile.row == 3 && tile.col == 3,
        );

        expect(
          centerTile.kind,
          isIn([TerrainKind.water, TerrainKind.shore]),
        );
      }
    });

    test('centers generated game tiles on the player GPS position', () {
      final json = File('assets/maps/hk_terrain_mvp.json').readAsStringSync();
      final source = GeoTerrainDataSource(GeoTerrainDataset.fromJson(json));
      const player = LatLng(22.3517, 114.0743);

      final tiles = source.buildTiles(
        playerLatLng: player,
        rows: 15,
        cols: 11,
      );
      final centerTile = tiles.singleWhere(
        (tile) => tile.row == 7 && tile.col == 5,
      );

      expect(centerTile.centerLatLng.latitude, closeTo(player.latitude, 0.001));
      expect(
          centerTile.centerLatLng.longitude, closeTo(player.longitude, 0.001));
    });

    test('limits generated game tile viewport to roughly 500 meters radius',
        () {
      final json = File('assets/maps/hk_terrain_mvp.json').readAsStringSync();
      final source = GeoTerrainDataSource(GeoTerrainDataset.fromJson(json));
      const player = LatLng(22.3517, 114.0743);
      const distance = Distance();

      final tiles = source.buildTiles(
        playerLatLng: player,
        rows: 23,
        cols: 17,
      );
      final farthestMeters = tiles
          .map((tile) =>
              distance.as(LengthUnit.Meter, player, tile.centerLatLng))
          .reduce((a, b) => a > b ? a : b);

      expect(farthestMeters, lessThanOrEqualTo(750));
    });

    test('returns no dataset fishing nodes when visible spots are empty', () {
      final json = File('assets/maps/hk_terrain_mvp.json').readAsStringSync();
      final source = GeoTerrainDataSource(GeoTerrainDataset.fromJson(json));

      final points = source.projectFishingNodes(const []);

      expect(points, isEmpty);
    });

    test('classifies terrain from polygon and line geometry', () {
      final source = GeoTerrainDataSource(GeoTerrainDataset.fromJson('''
{
  "schemaVersion": 3,
  "features": [
    {
      "kind": "water",
      "name": "geometry water",
      "lat": 22.35,
      "lng": 114.07,
      "radiusMeters": 1,
      "geometry": {
        "type": "polygon",
        "coordinates": [
          [22.405, 114.000],
          [22.405, 114.080],
          [22.300, 114.080],
          [22.300, 114.000]
        ]
      }
    },
    {
      "kind": "land",
      "name": "geometry land",
      "lat": 22.35,
      "lng": 114.14,
      "radiusMeters": 1,
      "geometry": {
        "type": "polygon",
        "coordinates": [
          [22.405, 114.080],
          [22.405, 114.170],
          [22.300, 114.170],
          [22.300, 114.080]
        ]
      }
    },
    {
      "kind": "road",
      "name": "geometry bridge road",
      "lat": 22.352,
      "lng": 114.075,
      "radiusMeters": 450,
      "geometry": {
        "type": "lineString",
        "coordinates": [
          [22.355, 114.020],
          [22.350, 114.130]
        ]
      }
    }
  ]
}
'''));

      final tiles = source.buildTiles(
        playerLatLng: const LatLng(22.35, 114.08),
        rows: 15,
        cols: 11,
      );
      final kinds = tiles.map((tile) => tile.kind).toSet();

      expect(kinds, contains(TerrainKind.water));
      expect(kinds, contains(TerrainKind.land));
      expect(kinds, contains(TerrainKind.road));
    });

    test('exposes nearby vector geometry for game map overlays', () {
      final json = File('assets/maps/hk_terrain_mvp.json').readAsStringSync();
      final source = GeoTerrainDataSource(GeoTerrainDataset.fromJson(json));

      final features = source.visibleVectorFeatures(
        playerLatLng: const LatLng(22.3517, 114.0743),
        radiusMeters: 900,
      );

      expect(
          features.map((feature) => feature.kind), contains(TerrainKind.road));
      expect(
          features.map((feature) => feature.kind), contains(TerrainKind.water));
      expect(features.every((feature) => feature.points.length >= 2), isTrue);
    });

    test('preserves road metadata from JSON through visible vector features',
        () {
      final source = GeoTerrainDataSource(GeoTerrainDataset.fromJson('''
{
  "schemaVersion": 3,
  "features": [
    {
      "kind": "road",
      "name": "大涌橋路",
      "roadClass": "primary",
      "isBridge": true,
      "lanes": 3,
      "lat": 22.3792,
      "lng": 114.1923,
      "radiusMeters": 50,
      "geometry": {
        "type": "lineString",
        "coordinates": [[22.3790, 114.1910], [22.3800, 114.1930]]
      }
    }
  ]
}
'''));

      final parsed = source.dataset.features.single;
      final vectorFeature = source
          .visibleVectorFeatures(
            playerLatLng: const LatLng(22.3792, 114.1923),
            radiusMeters: 500,
          )
          .single;

      expect(parsed.roadClass, RoadClass.primary);
      expect(parsed.isBridge, isTrue);
      expect(parsed.lanes, 3);
      expect(vectorFeature.roadClass, RoadClass.primary);
      expect(vectorFeature.isBridge, isTrue);
      expect(vectorFeature.lanes, 3);
    });

    test('exposes Sha Tin Hilton road vectors for the debug fishing spot', () {
      final json = File('assets/maps/hk_terrain_mvp.json').readAsStringSync();
      final source = GeoTerrainDataSource(GeoTerrainDataset.fromJson(json));

      final features = source.visibleVectorFeatures(
        playerLatLng: const LatLng(22.3819, 114.1874),
        radiusMeters: 900,
      );
      final names = features.map((feature) => feature.name).toSet();

      expect(
          features.map((feature) => feature.kind), contains(TerrainKind.road));
      expect(names, contains('沙田正街'));
      expect(names, contains('源禾路'));
      expect(names, contains('大涌橋路'));
    });

    test('exposes real roads around major Hong Kong fishing regions', () {
      final json = File('assets/maps/hk_terrain_mvp.json').readAsStringSync();
      final source = GeoTerrainDataSource(GeoTerrainDataset.fromJson(json));
      const anchors = <String, LatLng>{
        'central-harbour': LatLng(22.2860, 114.1626),
        'north-point': LatLng(22.2937, 114.1985),
        'sai-kung': LatLng(22.3815, 114.2754),
        'tai-po': LatLng(22.4425, 114.1840),
        'sam-mun-tsai': LatLng(22.4555, 114.2132),
        'tung-chung': LatLng(22.2942, 113.9404),
        'cheung-chau': LatLng(22.2080, 114.0285),
        'stanley': LatLng(22.2173, 114.2102),
      };

      for (final entry in anchors.entries) {
        final roads = source
            .visibleVectorFeatures(
              playerLatLng: entry.value,
              radiusMeters: 900,
            )
            .where((feature) => feature.kind == TerrainKind.road);
        expect(roads, isNotEmpty, reason: '${entry.key} should expose roads');
      }
    });

    test('reuses tiles while the GPS center is unchanged', () {
      final json = File('assets/maps/hk_terrain_mvp.json').readAsStringSync();
      final source = GeoTerrainDataSource(GeoTerrainDataset.fromJson(json));
      const center = LatLng(22.3524, 114.0739);

      final first = source.buildTiles(
        playerLatLng: center,
        rows: 29,
        cols: 21,
      );
      final second = source.buildTiles(
        playerLatLng: center,
        rows: 29,
        cols: 21,
      );

      expect(identical(first, second), isTrue);
    });

    test('parses and exposes a closed building polygon with height', () {
      final dataset = GeoTerrainDataset.fromJson('''
      {"features":[{"kind":"building","name":"Hilton Centre",
      "lat":22.3819,"lng":114.1874,"radiusMeters":40,"heightMeters":31,
      "geometry":{"type":"polygon","coordinates":[
      [22.3818,114.1873],[22.3818,114.1875],[22.3820,114.1875],
      [22.3820,114.1873],[22.3818,114.1873]]}}]}''');
      final source = GeoTerrainDataSource(dataset);
      final feature = source
          .visibleVectorFeatures(
            playerLatLng: const LatLng(22.3819, 114.1874),
            radiusMeters: 500,
          )
          .single;

      expect(feature.kind, TerrainKind.building);
      expect(feature.isClosed, isTrue);
      expect(feature.heightMeters, 31);
    });

    test('prunes distant roads before tile classification', () {
      final features = <GeoTerrainFeature>[
        const GeoTerrainFeature(
          kind: TerrainKind.road,
          name: 'nearby road',
          lat: 22.3522,
          lng: 114.0740,
          radiusMeters: 50,
          geometry: GeoTerrainGeometry(
            type: 'lineString',
            coordinates: [
              LatLng(22.3520, 114.0730),
              LatLng(22.3525, 114.0750),
            ],
          ),
        ),
        for (var index = 0; index < 200; index++)
          GeoTerrainFeature(
            kind: TerrainKind.road,
            name: 'distant road $index',
            lat: 22.55 + index * 0.00001,
            lng: 114.25,
            radiusMeters: 50,
            geometry: GeoTerrainGeometry(
              type: 'lineString',
              coordinates: [
                LatLng(22.55 + index * 0.00001, 114.25),
                LatLng(22.551 + index * 0.00001, 114.251),
              ],
            ),
          ),
      ];
      final source = GeoTerrainDataSource(
        GeoTerrainDataset(features: features),
      );

      expect(
        source.candidateFeatureCount(
          const LatLng(22.3517, 114.0743),
          TerrainKind.road,
        ),
        1,
      );
    });
  });
}
