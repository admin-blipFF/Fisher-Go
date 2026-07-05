import 'dart:io';

import 'package:fishergo/features/game_home/domain/terrain_data_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
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

    test('classifies Tsing Ma area from real terrain features', () {
      final json = File('assets/maps/hk_terrain_mvp.json').readAsStringSync();
      final source = GeoTerrainDataSource(GeoTerrainDataset.fromJson(json));

      final tiles = source.buildTiles(
        playerLatLng: const LatLng(22.3517, 114.0743),
        rows: 15,
        cols: 11,
      );
      final kinds = tiles.map((tile) => tile.kind).toSet();

      expect(kinds, contains(TerrainKind.water));
      expect(kinds, contains(TerrainKind.land));
      expect(kinds, contains(TerrainKind.road));
      expect(kinds, contains(TerrainKind.fishingNode));
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
  });
}
