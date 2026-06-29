import 'dart:ui';

import 'package:fishergo/features/game_home/domain/game_map_camera.dart';
import 'package:fishergo/features/game_home/domain/game_map_feature_store.dart';
import 'package:fishergo/features/game_home/domain/terrain_data_source.dart';
import 'package:fishergo/features/game_home/presentation/game_map_renderer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

const center = LatLng(22.331, 114.103);
const viewport = Size(390, 780);

void main() {
  GameMapPainter painter({
    double bearing = 0,
    List<TerrainTile>? tiles,
    List<TerrainVectorFeature>? features,
    List<ProjectedFishingSpot>? spots,
  }) {
    final camera = GameMapCamera(
      center: center,
      visibleRadiusMeters: 500,
      bearingDegrees: bearing,
      viewportSize: viewport,
    );
    return GameMapPainter(
      camera: camera,
      terrainTiles: tiles ?? [_waterTile()],
      terrainFeatures: features ?? [_roadFeature()],
      fishingSpots: spots ?? [_projectedSpot(camera)],
    );
  }

  test('does not repaint for equivalent map inputs', () {
    expect(painter().shouldRepaint(painter()), isFalse);
  });

  test('repaints when camera, terrain, or fishing spots change', () {
    expect(painter(bearing: 15).shouldRepaint(painter()), isTrue);

    expect(
      painter(features: [_waterFeature()]).shouldRepaint(painter()),
      isTrue,
    );

    expect(
      painter(tiles: [_roadTile()]).shouldRepaint(painter()),
      isTrue,
    );

    final movedCamera = const GameMapCamera(
      center: center,
      visibleRadiusMeters: 500,
      bearingDegrees: 0,
      viewportSize: viewport,
    );
    expect(
      painter(
        spots: [
          ProjectedFishingSpot(
            id: 'spot-a',
            name: 'Spot A',
            position: center,
            screenPosition: movedCamera.project(
              const LatLng(22.3313, 114.103),
            ),
          ),
        ],
      ).shouldRepaint(painter()),
      isTrue,
    );
  });
}

TerrainTile _waterTile() {
  return const TerrainTile(
    kind: TerrainKind.water,
    row: 0,
    col: 0,
    centerLatLng: center,
  );
}

TerrainTile _roadTile() {
  return const TerrainTile(
    kind: TerrainKind.road,
    row: 0,
    col: 0,
    centerLatLng: center,
  );
}

TerrainVectorFeature _roadFeature() {
  return const TerrainVectorFeature(
    kind: TerrainKind.road,
    name: 'road',
    points: [
      LatLng(22.3308, 114.1028),
      LatLng(22.3312, 114.1032),
    ],
    isClosed: false,
  );
}

TerrainVectorFeature _waterFeature() {
  return const TerrainVectorFeature(
    kind: TerrainKind.water,
    name: 'water',
    points: [
      LatLng(22.3308, 114.1028),
      LatLng(22.3312, 114.1032),
    ],
    isClosed: false,
  );
}

ProjectedFishingSpot _projectedSpot(GameMapCamera camera) {
  return ProjectedFishingSpot(
    id: 'spot-a',
    name: 'Spot A',
    position: center,
    screenPosition: camera.project(center),
  );
}
