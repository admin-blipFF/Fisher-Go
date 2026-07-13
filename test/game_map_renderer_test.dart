import 'dart:io';
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
    double perspectiveStrength = 0,
    double viewportAnchorY = 0.5,
    List<TerrainTile>? tiles,
    List<TerrainVectorFeature>? features,
    List<ProjectedFishingSpot>? spots,
  }) {
    final camera = GameMapCamera(
      center: center,
      visibleRadiusMeters: 500,
      bearingDegrees: bearing,
      viewportSize: viewport,
      perspectiveStrength: perspectiveStrength,
      viewportAnchorY: viewportAnchorY,
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

  test('repaints when perspective projection settings change', () {
    expect(
      painter(perspectiveStrength: 0.3).shouldRepaint(painter()),
      isTrue,
    );
    expect(
      painter(viewportAnchorY: 0.42).shouldRepaint(painter()),
      isTrue,
    );
  });

  test('repaints when building height or OSM provenance changes', () {
    expect(
      painter(
        features: [_buildingFeature(heightMeters: 36)],
      ).shouldRepaint(
        painter(features: [_buildingFeature(heightMeters: 24)]),
      ),
      isTrue,
    );
    expect(
      painter(features: [_waterFeature(osmId: 42)]).shouldRepaint(
        painter(features: [_waterFeature()]),
      ),
      isTrue,
    );
    expect(
      painter(
        features: [
          _waterFeature(
            provenance: TerrainFeatureProvenance.openStreetMap,
          ),
        ],
      ).shouldRepaint(painter(features: [_waterFeature()])),
      isTrue,
    );
  });

  test('uses a low-cost render budget for dense web map scenes', () {
    final budget = GameMapRenderBudget.forScene(
      terrainTileCount: 29 * 21,
      terrainFeatureCount: 80,
    );

    expect(budget.enableDecorativeOverlays, isFalse);
    expect(budget.enableVectorTransitions, isFalse);
    expect(budget.enableRoadMicroDetails, isFalse);
    expect(budget.maxWashTiles, lessThan(29 * 21));
    expect(budget.maxVeilTiles, lessThan(budget.maxWashTiles));
    expect(budget.maxLabels, lessThan(7));
    expect(budget.maxBuildings, lessThan(80));
    expect(budget.enableBuildingRoofDetail, isFalse);
  });

  test('keeps full visual detail for compact map scenes', () {
    final budget = GameMapRenderBudget.forScene(
      terrainTileCount: 15 * 11,
      terrainFeatureCount: 18,
    );

    expect(budget.enableDecorativeOverlays, isTrue);
    expect(budget.enableVectorTransitions, isTrue);
    expect(budget.enableRoadMicroDetails, isTrue);
    expect(budget.maxLabels, 7);
    expect(budget.maxBuildings, 72);
    expect(budget.enableBuildingRoofDetail, isTrue);
  });

  test('building textures use the same terrain surface as land', () async {
    final image = await _testImage();
    final textures = GameMapTexturePack(land: image);

    expect(
      textures.imageFor(TerrainKind.building),
      same(textures.imageFor(TerrainKind.land)),
    );
  });

  test('rejects open and underspecified building footprints', () {
    expect(
      isRenderableBuildingFeature(
        _buildingFeature(isClosed: false, pointCount: 4),
      ),
      isFalse,
    );
    expect(
      isRenderableBuildingFeature(
        _buildingFeature(isClosed: true, pointCount: 3),
      ),
      isFalse,
    );
    expect(
      isRenderableBuildingFeature(
        _buildingFeature(isClosed: true, pointCount: 4),
      ),
      isTrue,
    );
  });

  test('coastline depth accepts OSM geometry but rejects manual polygons', () {
    expect(
      isRenderableCoastlineDepthFeature(
        _waterFeature(provenance: TerrainFeatureProvenance.openStreetMap),
      ),
      isTrue,
    );
    expect(
      isRenderableCoastlineDepthFeature(_waterFeature(osmId: 42)),
      isTrue,
      reason: 'legacy bundles with osmId remain compatible',
    );
    expect(
      isRenderableCoastlineDepthFeature(_waterFeature()),
      isFalse,
    );
  });

  test('sampled water cells share one viewport-space gradient', () {
    const cellBounds = Rect.fromLTWH(20, 40, 60, 80);
    const viewportBounds = Rect.fromLTWH(0, 0, 390, 780);

    expect(
      terrainGradientBoundsFor(
        kind: TerrainKind.water,
        cellBounds: cellBounds,
        viewportBounds: viewportBounds,
      ),
      viewportBounds,
    );
  });

  test('sampled coastline blend spans enough of a cell to hide grid steps', () {
    expect(terrainBoundaryBlendWidth(50), 39);
    expect(terrainBoundaryBlendWidth(12), 18);
  });

  test('current bundle distinguishes cached coastlines from manual polygons',
      () {
    final dataset = GeoTerrainDataset.fromJson(
      File('assets/maps/hk_terrain_mvp.json').readAsStringSync(),
    );
    final source = GeoTerrainDataSource(dataset);
    final cachedGeo = dataset.features.singleWhere(
      (feature) => feature.name == 'OSM 汲水門水域',
    );
    final manualGeo = dataset.features.singleWhere(
      (feature) => feature.name == '維多利亞港海面',
    );
    final cachedVector = source
        .visibleVectorFeatures(
          playerLatLng: cachedGeo.center,
          radiusMeters: 1000,
        )
        .singleWhere((feature) => feature.name == cachedGeo.name);
    final manualVector = source
        .visibleVectorFeatures(
          playerLatLng: manualGeo.center,
          radiusMeters: 1000,
        )
        .singleWhere((feature) => feature.name == manualGeo.name);

    expect(cachedGeo.osmId, isNull);
    expect(cachedGeo.provenance, TerrainFeatureProvenance.openStreetMap);
    expect(isRenderableCoastlineDepthFeature(cachedVector), isTrue);
    expect(manualGeo.provenance, isNull);
    expect(isRenderableCoastlineDepthFeature(manualVector), isFalse);
  });

  test('building cap ignores buffered geometry outside projected viewport', () {
    final camera = _camera();
    final candidates = selectBuildingCandidates(
      features: [
        _polygonBuilding(
          'buffered offscreen',
          const [
            LatLng(22.33095, 114.10595),
            LatLng(22.33095, 114.10605),
            LatLng(22.33105, 114.10605),
            LatLng(22.33095, 114.10595),
          ],
        ),
        _polygonBuilding(
          'visible',
          const [
            LatLng(22.33095, 114.10295),
            LatLng(22.33095, 114.10305),
            LatLng(22.33105, 114.10305),
            LatLng(22.33095, 114.10295),
          ],
        ),
      ],
      camera: camera,
      viewportSize: viewport,
      maxBuildings: 1,
    );

    expect(candidates.map((candidate) => candidate.feature.name), ['visible']);
  });

  test('building selection retains crossing and enclosing polygons', () {
    final camera = _camera();
    final crossing = _polygonBuilding(
      'crossing',
      const [
        LatLng(22.3309, 114.0998),
        LatLng(22.3309, 114.1062),
        LatLng(22.3311, 114.1062),
        LatLng(22.3311, 114.0998),
        LatLng(22.3309, 114.0998),
      ],
    );
    final enclosing = _polygonBuilding(
      'enclosing',
      const [
        LatLng(22.326, 114.0998),
        LatLng(22.326, 114.1062),
        LatLng(22.336, 114.1062),
        LatLng(22.336, 114.0998),
        LatLng(22.326, 114.0998),
      ],
    );

    bool hasVertexInViewport(TerrainVectorFeature feature) => feature.points
        .map(camera.project)
        .any((point) => (Offset.zero & viewport).contains(point));
    expect(hasVertexInViewport(crossing), isFalse);
    expect(hasVertexInViewport(enclosing), isFalse);

    final candidates = selectBuildingCandidates(
      features: [crossing, enclosing],
      camera: camera,
      viewportSize: viewport,
      maxBuildings: 2,
    );

    expect(
      candidates.map((candidate) => candidate.feature.name).toSet(),
      {'crossing', 'enclosing'},
    );
  });

  test('building selection sorts capped candidates far-to-near', () {
    final candidates = selectBuildingCandidates(
      features: [
        _buildingAt('near', const LatLng(22.3302, 114.103)),
        _buildingAt('far', const LatLng(22.3318, 114.103)),
      ],
      camera: _camera(perspectiveStrength: 0.3),
      viewportSize: viewport,
      maxBuildings: 2,
    );

    expect(
      candidates.map((candidate) => candidate.feature.name),
      ['far', 'near'],
    );
  });
}

GameMapCamera _camera({double perspectiveStrength = 0}) => GameMapCamera(
      center: center,
      visibleRadiusMeters: 500,
      bearingDegrees: 0,
      viewportSize: viewport,
      perspectiveStrength: perspectiveStrength,
    );

TerrainVectorFeature _buildingAt(String name, LatLng point) {
  const delta = 0.00005;
  return _polygonBuilding(name, [
    LatLng(point.latitude - delta, point.longitude - delta),
    LatLng(point.latitude - delta, point.longitude + delta),
    LatLng(point.latitude + delta, point.longitude + delta),
    LatLng(point.latitude - delta, point.longitude - delta),
  ]);
}

TerrainVectorFeature _polygonBuilding(String name, List<LatLng> points) =>
    TerrainVectorFeature(
      kind: TerrainKind.building,
      name: name,
      points: points,
      isClosed: true,
      heightMeters: 24,
      osmId: 1,
    );

Future<Image> _testImage() {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 1, 1),
    Paint()..color = const Color(0xFFFFFFFF),
  );
  return recorder.endRecording().toImage(1, 1);
}

TerrainVectorFeature _buildingFeature({
  bool isClosed = true,
  int pointCount = 4,
  double heightMeters = 24,
}) {
  const points = [
    LatLng(22.3308, 114.1028),
    LatLng(22.3308, 114.1032),
    LatLng(22.3312, 114.1032),
    LatLng(22.3308, 114.1028),
  ];
  return TerrainVectorFeature(
    kind: TerrainKind.building,
    name: 'Block',
    points: points.take(pointCount).toList(growable: false),
    isClosed: isClosed,
    heightMeters: heightMeters,
  );
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

TerrainVectorFeature _waterFeature({
  int? osmId,
  TerrainFeatureProvenance? provenance,
}) {
  return TerrainVectorFeature(
    kind: TerrainKind.water,
    name: 'water',
    points: const [
      LatLng(22.3308, 114.1028),
      LatLng(22.3312, 114.1032),
    ],
    isClosed: false,
    osmId: osmId,
    provenance: provenance,
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
