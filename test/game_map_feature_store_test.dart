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

    test('keeps east fishing spot to the right after projection', () {
      const dataset = GeoTerrainDataset(features: []);
      const eastSpot = GameMapFishingSpot(
        id: 'east-node',
        name: 'East Node',
        position: LatLng(22.3517, 114.0783),
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
        spots: const [eastSpot],
      );

      expect(markers, hasLength(1));
      expect(markers.single.screenPosition.dx, greaterThan(195));
      expect(markers.single.screenPosition.dy, closeTo(422, 0.01));
    });

    test('bearing rotates east fishing spot below the player', () {
      const dataset = GeoTerrainDataset(features: []);
      const eastSpot = GameMapFishingSpot(
        id: 'east-node',
        name: 'East Node',
        position: LatLng(22.3517, 114.0783),
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
        spots: const [eastSpot],
      );

      expect(markers, hasLength(1));
      expect(markers.single.screenPosition.dx, closeTo(195, 8));
      expect(markers.single.screenPosition.dy, greaterThan(422));
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

    test('prunes distant terrain before precise projection', () {
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
      final store = GameMapFeatureStore(
        dataset: GeoTerrainDataset(features: features),
      );
      final camera = GameMapCamera(
        center: const LatLng(22.3517, 114.0743),
        visibleRadiusMeters: 500,
        bearingDegrees: 0,
        viewportSize: const Size(390, 844),
      );

      expect(store.candidateFeatureCount(camera), 1);
      expect(store.visibleTerrainFeatures(camera).single.name, 'nearby road');
    });

    test('preserves building height in visible terrain features', () {
      final dataset = GeoTerrainDataset.fromJson('''
      {"features":[{"kind":"building","name":"Hilton Centre",
      "lat":22.3819,"lng":114.1874,"radiusMeters":40,"heightMeters":31,
      "osmId":789012,
      "geometry":{"type":"polygon","coordinates":[
      [22.3818,114.1873],[22.3818,114.1875],[22.3820,114.1875],
      [22.3820,114.1873],[22.3818,114.1873]]}}]}''');
      final store = GameMapFeatureStore(dataset: dataset);
      final camera = GameMapCamera(
        center: const LatLng(22.3819, 114.1874),
        visibleRadiusMeters: 500,
        bearingDegrees: 0,
        viewportSize: const Size(390, 844),
      );

      final feature = store.visibleTerrainFeatures(camera).single;

      expect(feature.kind, TerrainKind.building);
      expect(feature.heightMeters, 31);
      expect(feature.osmId, 789012);
      expect(feature.isOsmDerived, isTrue);
    });

    test('preserves explicit OSM provenance without an osmId', () {
      final dataset = GeoTerrainDataset.fromJson('''
      {"features":[{"kind":"land","name":"Cached coast land",
      "provenance":"openStreetMap",
      "lat":22.3819,"lng":114.1874,"radiusMeters":40,
      "geometry":{"type":"polygon","coordinates":[
      [22.3818,114.1873],[22.3818,114.1875],[22.3820,114.1875],
      [22.3818,114.1873]]}}]}''');
      final store = GameMapFeatureStore(dataset: dataset);
      final camera = GameMapCamera(
        center: const LatLng(22.3819, 114.1874),
        visibleRadiusMeters: 500,
        bearingDegrees: 0,
        viewportSize: const Size(390, 844),
      );

      final feature = store.visibleTerrainFeatures(camera).single;

      expect(feature.osmId, isNull);
      expect(feature.provenance, TerrainFeatureProvenance.openStreetMap);
      expect(feature.isOsmDerived, isTrue);
    });
  });
}
