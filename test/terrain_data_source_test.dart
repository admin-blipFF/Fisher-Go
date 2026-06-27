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

    test('provides fallback fishing nodes when no visible spots are available',
        () {
      const source = LocalTerrainDataSource();
      final points = source.projectFishingNodes(const []);

      expect(points, hasLength(4));
      expect(points.first.dx, 0.18);
      expect(points.first.dy, 0.42);
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
      expect(kinds, contains(TerrainKind.pier));
      expect(kinds, contains(TerrainKind.fishingNode));
    });

    test('uses dataset fishing nodes when visible spots are empty', () {
      final json = File('assets/maps/hk_terrain_mvp.json').readAsStringSync();
      final source = GeoTerrainDataSource(GeoTerrainDataset.fromJson(json));

      final points = source.projectFishingNodes(const []);

      expect(points.length, greaterThanOrEqualTo(4));
      for (final point in points) {
        expect(point.dx, inInclusiveRange(0.12, 0.88));
        expect(point.dy, inInclusiveRange(0.22, 0.82));
      }
    });
  });
}
