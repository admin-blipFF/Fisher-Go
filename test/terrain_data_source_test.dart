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
}
