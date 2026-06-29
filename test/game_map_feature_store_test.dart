import 'dart:io';
import 'dart:ui' show Size;

import 'package:fishergo/features/game_home/domain/game_map_camera.dart';
import 'package:fishergo/features/game_home/domain/game_map_feature_store.dart';
import 'package:fishergo/features/game_home/domain/terrain_data_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('GameMapFeatureStore', () {
    test('exposes visible terrain vectors around Tsing Ma', () {
      final json = File('assets/maps/hk_terrain_mvp.json').readAsStringSync();
      final dataset = GeoTerrainDataset.fromJson(json);
      final store = GameMapFeatureStore(dataset: dataset);
      final camera = GameMapCamera(
        center: const LatLng(22.3517, 114.0743),
        visibleRadiusMeters: 500,
        bearingDegrees: 0,
        viewportSize: const Size(390, 844),
      );

      final features = store.visibleTerrainFeatures(camera);

      expect(
          features.map((feature) => feature.kind), contains(TerrainKind.road));
      expect(
        features.map((feature) => feature.kind),
        contains(TerrainKind.water),
      );
      expect(features.every((feature) => feature.points.length >= 2), isTrue);
    });

    test('projects fishing spots through the same camera', () {
      const dataset = GeoTerrainDataset(features: []);
      const spot = GameMapFishingSpot(
        id: 'center-node',
        name: 'Center Node',
        position: LatLng(22.3517, 114.0743),
      );
      final store = GameMapFeatureStore(dataset: dataset);
      final camera = GameMapCamera(
        center: const LatLng(22.3517, 114.0743),
        visibleRadiusMeters: 500,
        bearingDegrees: 0,
        viewportSize: const Size(390, 844),
      );

      final markers = store.projectFishingSpots(
        camera: camera,
        spots: const [spot],
      );

      expect(markers, hasLength(1));
      expect(markers.single.id, spot.id);
      expect(markers.single.name, spot.name);
      expect(markers.single.position, spot.position);
      expect(markers.single.screenPosition.dx, closeTo(195, 0.01));
      expect(markers.single.screenPosition.dy, closeTo(422, 0.01));
    });

    test('rotates projected fishing spots with camera bearing', () {
      const dataset = GeoTerrainDataset(features: []);
      const northSpot = GameMapFishingSpot(
        id: 'north-node',
        name: 'North Node',
        position: LatLng(22.3562, 114.0743),
      );
      final store = GameMapFeatureStore(dataset: dataset);
      final camera = GameMapCamera(
        center: const LatLng(22.3517, 114.0743),
        visibleRadiusMeters: 500,
        bearingDegrees: 90,
        viewportSize: const Size(390, 844),
      );

      final markers = store.projectFishingSpots(
        camera: camera,
        spots: const [northSpot],
      );

      expect(markers, hasLength(1));
      expect(markers.single.screenPosition.dx, greaterThan(195));
      expect(markers.single.screenPosition.dy, closeTo(422, 8));
    });

    test('keeps long lineString visible when only its segment crosses viewport',
        () {
      const dataset = GeoTerrainDataset(
        features: [
          GeoTerrainFeature(
            kind: TerrainKind.road,
            name: 'Harbour Crossing',
            lat: 23,
            lng: 115,
            radiusMeters: 10,
            geometry: GeoTerrainGeometry(
              type: 'lineString',
              coordinates: [
                LatLng(22.3517, 114.0543),
                LatLng(22.3517, 114.0943),
              ],
            ),
          ),
        ],
      );
      final store = GameMapFeatureStore(dataset: dataset);
      final camera = GameMapCamera(
        center: const LatLng(22.3517, 114.0743),
        visibleRadiusMeters: 500,
        bearingDegrees: 0,
        viewportSize: const Size(390, 844),
      );

      final features = store.visibleTerrainFeatures(camera);

      expect(features, hasLength(1));
      expect(features.single.name, 'Harbour Crossing');
    });

    test('keeps polygon visible when an edge crosses the viewport', () {
      const dataset = GeoTerrainDataset(
        features: [
          GeoTerrainFeature(
            kind: TerrainKind.water,
            name: 'Long Harbour Edge',
            lat: 23,
            lng: 115,
            radiusMeters: 10,
            geometry: GeoTerrainGeometry(
              type: 'polygon',
              coordinates: [
                LatLng(22.3527, 114.0543),
                LatLng(22.3527, 114.0943),
                LatLng(22.3537, 114.0943),
                LatLng(22.3537, 114.0543),
              ],
            ),
          ),
        ],
      );
      final store = GameMapFeatureStore(dataset: dataset);
      final camera = GameMapCamera(
        center: const LatLng(22.3517, 114.0743),
        visibleRadiusMeters: 500,
        bearingDegrees: 0,
        viewportSize: const Size(390, 844),
      );

      final features = store.visibleTerrainFeatures(camera);

      expect(features, hasLength(1));
      expect(features.single.name, 'Long Harbour Edge');
      expect(features.single.isClosed, isTrue);
    });

    test('keeps polygon visible when only its closing edge crosses viewport',
        () {
      const dataset = GeoTerrainDataset(
        features: [
          GeoTerrainFeature(
            kind: TerrainKind.water,
            name: 'Implicit Harbour Edge',
            lat: 23,
            lng: 115,
            radiusMeters: 10,
            geometry: GeoTerrainGeometry(
              type: 'polygon',
              coordinates: [
                LatLng(22.3545101, 114.0669531),
                LatLng(22.3660269, 114.0654588),
                LatLng(22.3660269, 114.0831412),
                LatLng(22.3545101, 114.0818960),
              ],
            ),
          ),
        ],
      );
      final store = GameMapFeatureStore(dataset: dataset);
      final camera = GameMapCamera(
        center: const LatLng(22.3517, 114.0743),
        visibleRadiusMeters: 500,
        bearingDegrees: 0,
        viewportSize: const Size(390, 844),
      );

      final features = store.visibleTerrainFeatures(camera);

      expect(features, hasLength(1));
      expect(features.single.name, 'Implicit Harbour Edge');
      expect(features.single.isClosed, isTrue);
    });

    test('excludes fishingNode geometry from visible terrain features', () {
      const dataset = GeoTerrainDataset(
        features: [
          GeoTerrainFeature(
            kind: TerrainKind.fishingNode,
            name: 'Node Geometry',
            lat: 22.3517,
            lng: 114.0743,
            radiusMeters: 20,
            geometry: GeoTerrainGeometry(
              type: 'lineString',
              coordinates: [
                LatLng(22.3517, 114.0733),
                LatLng(22.3517, 114.0753),
              ],
            ),
          ),
        ],
      );
      final store = GameMapFeatureStore(dataset: dataset);
      final camera = GameMapCamera(
        center: const LatLng(22.3517, 114.0743),
        visibleRadiusMeters: 500,
        bearingDegrees: 0,
        viewportSize: const Size(390, 844),
      );

      final features = store.visibleTerrainFeatures(camera);

      expect(features, isEmpty);
    });

    test('filters out invisible fishing spots', () {
      const dataset = GeoTerrainDataset(features: []);
      const visibleSpot = GameMapFishingSpot(
        id: 'center-node',
        name: 'Center Node',
        position: LatLng(22.3517, 114.0743),
      );
      const offscreenSpot = GameMapFishingSpot(
        id: 'far-node',
        name: 'Far Node',
        position: LatLng(22.3517, 114.0940),
      );
      final store = GameMapFeatureStore(dataset: dataset);
      final camera = GameMapCamera(
        center: const LatLng(22.3517, 114.0743),
        visibleRadiusMeters: 500,
        bearingDegrees: 0,
        viewportSize: const Size(390, 844),
      );

      final markers = store.projectFishingSpots(
        camera: camera,
        spots: const [visibleSpot, offscreenSpot],
      );

      expect(markers, hasLength(1));
      expect(markers.single.id, visibleSpot.id);
    });
  });
}
