# Realistic OSM Surfaces Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Render real Hong Kong coastline depth bands and OSM-derived 2.5D buildings in the shared rotatable FisherGO Web/Android game map.

**Architecture:** Extend the existing bundled terrain schema with closed building polygons and optional height metadata, keeping OSM geometry as the position source of truth. Put deterministic depth/style calculations in a focused domain class and keep `GameMapPainter` responsible only for ordered vector drawing under the existing `GameMapCamera` and render budget.

**Tech Stack:** Flutter/Dart, `CustomPainter`, `latlong2`, bundled JSON terrain assets, OpenStreetMap-derived cache data, Flutter test.

## Global Constraints

- OpenStreetMap geometry remains the source of truth for water, coastline, land, roads, piers, bridges, and buildings.
- Generated imagery may provide seamless surface material only; it must never determine feature position or shape.
- Web and Android use the same Dart renderer and bundled offline JSON.
- Every geographic layer uses the same `GameMapCamera` projection, bearing, and perspective transform.
- Dense Web scenes simplify building detail instead of blocking gestures or dropping the map.
- Do not add continuous animation loops or a WebGL/3D engine.
- Never fabricate fishing spots or replace current clickable 3D fishing markers with yellow points.
- Android verification uses `FisherGO_API35` only and excludes device `0123456789ABCDEF`.

---

### Task 1: Building Terrain Schema And Feature Store

**Files:**
- Modify: `lib/features/game_home/domain/terrain_data_source.dart`
- Modify: `lib/features/game_home/domain/game_map_feature_store.dart`
- Test: `test/terrain_data_source_test.dart`
- Test: `test/game_map_feature_store_test.dart`

**Interfaces:**
- Produces: `TerrainKind.building`
- Produces: `GeoTerrainFeature.heightMeters` and `TerrainVectorFeature.heightMeters` as nullable `double`
- Consumes: existing `GeoTerrainDataset.fromJson`, `GeoTerrainDataSource.visibleVectorFeatures`, and `GameMapFeatureStore.visibleTerrainFeatures`

- [ ] **Step 1: Write failing JSON and visibility tests**

```dart
test('parses and exposes a closed building polygon with height', () {
  final dataset = GeoTerrainDataset.fromJson('''
  {"features":[{"kind":"building","name":"Hilton Centre",
  "lat":22.3819,"lng":114.1874,"radiusMeters":40,"heightMeters":31,
  "geometry":{"type":"polygon","coordinates":[
  [22.3818,114.1873],[22.3818,114.1875],[22.3820,114.1875],
  [22.3820,114.1873],[22.3818,114.1873]]}}]}''');
  final source = GeoTerrainDataSource(dataset);
  final feature = source.visibleVectorFeatures(
    playerLatLng: const LatLng(22.3819, 114.1874),
    radiusMeters: 500,
  ).single;

  expect(feature.kind, TerrainKind.building);
  expect(feature.isClosed, isTrue);
  expect(feature.heightMeters, 31);
});
```

- [ ] **Step 2: Run tests and verify RED**

Run: `flutter test test/terrain_data_source_test.dart test/game_map_feature_store_test.dart -r compact`

Expected: compilation fails because `TerrainKind.building` and `heightMeters` do not exist.

- [ ] **Step 3: Implement the schema fields and propagation**

```dart
enum TerrainKind { water, shore, land, building, road, pier, fishingNode }

class TerrainVectorFeature {
  const TerrainVectorFeature({
    required this.kind,
    required this.name,
    required this.points,
    required this.isClosed,
    this.heightMeters,
    this.roadClass = RoadClass.unknown,
    this.isBridge = false,
    this.lanes,
  });

  final double? heightMeters;
}
```

Add the same nullable field to `GeoTerrainFeature`, parse `(raw['heightMeters'] as num?)?.toDouble()`, and copy it when producing `TerrainVectorFeature`.

- [ ] **Step 4: Run focused tests and verify GREEN**

Run: `flutter test test/terrain_data_source_test.dart test/game_map_feature_store_test.dart -r compact`

Expected: all focused tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/game_home/domain/terrain_data_source.dart lib/features/game_home/domain/game_map_feature_store.dart test/terrain_data_source_test.dart test/game_map_feature_store_test.dart
git commit -m "Add building geometry to terrain model"
```

### Task 2: OSM Building Cache Import And Bundled Asset

**Files:**
- Modify: `tool/generate_hk_terrain_mvp.dart`
- Modify: `data/hk_geo/osm_vector_cache.json`
- Modify: `assets/maps/hk_terrain_mvp.json`
- Test: `test/hk_terrain_generator_test.dart`

**Interfaces:**
- Consumes: cache features with `kind: "building"`, polygon geometry, and optional `heightMeters`
- Produces: deterministic bundled building records accepted by Task 1 schema

- [ ] **Step 1: Add a failing generator test for building retention**

```dart
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
  final building = (asset['features'] as List<Map<String, Object>>).single;
  expect(building['kind'], 'building');
  expect(building['heightMeters'], 24);
  expect((building['geometry'] as Map)['type'], 'polygon');
});
```

- [ ] **Step 2: Run the generator test and verify RED**

Run: `flutter test test/hk_terrain_generator_test.dart -r compact`

Expected: test fails because `_featureFromOsmCache` drops `heightMeters`.

- [ ] **Step 3: Preserve building metadata and add real cached footprints**

```dart
return _feature(
  kind: raw['kind'] as String,
  name: raw['name'] as String,
  // existing fields
  heightMeters: (raw['heightMeters'] as num?)?.toDouble(),
);
```

Extend `_feature` with `double? heightMeters` and emit rounded metadata. Add OSM-derived closed polygons around the existing Sha Tin test region and at least one waterfront verification region; include attribution and OSM IDs, and do not create geometry from visual guesses.

- [ ] **Step 4: Regenerate and verify the bundled asset**

Run: `dart run tool/generate_hk_terrain_mvp.dart`

Run: `flutter test test/hk_terrain_generator_test.dart test/terrain_data_source_test.dart -r compact`

Expected: generated asset equals the checked-in asset and all tests pass.

- [ ] **Step 5: Commit**

```bash
git add tool/generate_hk_terrain_mvp.dart data/hk_geo/osm_vector_cache.json assets/maps/hk_terrain_mvp.json test/hk_terrain_generator_test.dart
git commit -m "Bundle OSM building footprints"
```

### Task 3: Depth-Aware Building Style And Render Budget

**Files:**
- Create: `lib/features/game_home/domain/game_building_style.dart`
- Create: `test/game_building_style_test.dart`
- Modify: `lib/features/game_home/presentation/game_map_renderer.dart`
- Modify: `test/game_map_renderer_test.dart`

**Interfaces:**
- Produces: `GameBuildingStyle.forFeature(TerrainVectorFeature feature, {required double depthScale, required bool simplified})`
- Produces: `GameMapRenderBudget.maxBuildings` and `enableBuildingRoofDetail`
- Consumes: closed building geometry and `GameMapCamera.depthScaleFor`

- [ ] **Step 1: Write failing deterministic style and budget tests**

```dart
test('building style bounds perspective extrusion', () {
  const feature = TerrainVectorFeature(
    kind: TerrainKind.building,
    name: 'Block',
    points: [
      LatLng(22.0, 114.0), LatLng(22.0, 114.001),
      LatLng(22.001, 114.001), LatLng(22.0, 114.0),
    ],
    isClosed: true,
    heightMeters: 30,
  );
  final far = GameBuildingStyle.forFeature(
    feature, depthScale: 0.4, simplified: false);
  final near = GameBuildingStyle.forFeature(
    feature, depthScale: 1.6, simplified: false);
  expect(far.extrusionPixels, greaterThanOrEqualTo(3));
  expect(near.extrusionPixels, lessThanOrEqualTo(15));
  expect(near.extrusionPixels, greaterThan(far.extrusionPixels));
});
```

Extend dense-scene assertions with `expect(budget.maxBuildings, lessThan(80));` and `expect(budget.enableBuildingRoofDetail, isFalse);`.

- [ ] **Step 2: Run tests and verify RED**

Run: `flutter test test/game_building_style_test.dart test/game_map_renderer_test.dart -r compact`

Expected: compilation fails because style and budget fields do not exist.

- [ ] **Step 3: Implement minimal bounded style and budget**

```dart
class GameBuildingStyle {
  const GameBuildingStyle({
    required this.extrusionPixels,
    required this.roofColor,
    required this.sideColor,
    required this.outlineColor,
    required this.drawRoofDetail,
  });

  factory GameBuildingStyle.forFeature(
    TerrainVectorFeature feature, {
    required double depthScale,
    required bool simplified,
  }) {
    final height = (feature.heightMeters ?? 14).clamp(6, 60).toDouble();
    final extrusion = (height * 0.16 * depthScale).clamp(3, 15).toDouble();
    return GameBuildingStyle(
      extrusionPixels: extrusion,
      roofColor: const Color(0xFFD9E2DC),
      sideColor: const Color(0xFF728C91),
      outlineColor: const Color(0xFF28484E),
      drawRoofDetail: !simplified,
    );
  }
}
```

Set compact scenes to `maxBuildings: 72`, dense scenes to `maxBuildings: 30`, and disable roof detail for dense scenes.

- [ ] **Step 4: Run focused tests and verify GREEN**

Run: `flutter test test/game_building_style_test.dart test/game_map_renderer_test.dart -r compact`

Expected: all focused tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/game_home/domain/game_building_style.dart lib/features/game_home/presentation/game_map_renderer.dart test/game_building_style_test.dart test/game_map_renderer_test.dart
git commit -m "Define depth-aware building styles"
```

### Task 4: Coastline Bands And 2.5D Building Painter

**Files:**
- Modify: `lib/features/game_home/presentation/game_map_renderer.dart`
- Modify: `test/game_world_renderer_source_test.dart`
- Modify: `test/game_map_renderer_test.dart`

**Interfaces:**
- Consumes: Task 1 building features, Task 3 `GameBuildingStyle`, existing `_pathForFeature`, `camera.project`, and render budget
- Produces: `_drawCoastlineDepthLayer` and `_drawBuildingLayer` called between land and road layers

- [ ] **Step 1: Write failing layer-order and validity tests**

```dart
test('renderer orders coastline and buildings below roads and spots', () {
  final source = File(
    'lib/features/game_home/presentation/game_map_renderer.dart',
  ).readAsStringSync();
  final paint = source.substring(
    source.indexOf('void paint(Canvas canvas, Size size)'),
    source.indexOf('bool get _hasVectorWorldSurface'),
  );
  expect(paint.indexOf('_drawCoastlineDepthLayer'),
      lessThan(paint.indexOf('_drawBuildingLayer')));
  expect(paint.indexOf('_drawBuildingLayer'),
      lessThan(paint.indexOf('_drawRoadLayer')));
  expect(paint.indexOf('_drawRoadLayer'),
      lessThan(paint.indexOf('_drawFishingSpotLayer')));
});
```

Add a painter-facing helper test proving an open or fewer-than-three-point building is rejected by `isRenderableBuildingFeature`.

- [ ] **Step 2: Run tests and verify RED**

Run: `flutter test test/game_world_renderer_source_test.dart test/game_map_renderer_test.dart -r compact`

Expected: tests fail because the new layers/helper are absent.

- [ ] **Step 3: Implement coastline bands**

Draw each real water/land/shore path with three bounded strokes:

```dart
void _drawCoastlineDepthLayer(Canvas canvas, Size size) {
  for (final feature in terrainFeatures) {
    if (!const {TerrainKind.water, TerrainKind.land, TerrainKind.shore}
        .contains(feature.kind)) continue;
    final path = _pathForFeature(feature);
    if (path == null) continue;
    canvas.drawPath(path, submergedEdgePaint);
    canvas.drawPath(path, shallowBandPaint);
    canvas.drawPath(path, foamHighlightPaint);
  }
}
```

Use dark teal for the broad submerged edge, translucent turquoise for the middle band, and a narrow low-alpha warm-white foam line. Scale widths from a representative path point through `camera.depthScaleFor` and clamp them to avoid OSM segment jumps.

- [ ] **Step 4: Implement valid capped 2.5D buildings**

```dart
bool isRenderableBuildingFeature(TerrainVectorFeature feature) =>
    feature.kind == TerrainKind.building &&
    feature.isClosed &&
    feature.points.length >= 4;
```

For each visible building up to `budget.maxBuildings`, project the footprint, derive style from its midpoint depth, draw a translated side polygon and contact shadow first, then roof fill and outline. In simplified mode omit roof inset/detail and blur. Never synthesize a footprint.

- [ ] **Step 5: Run focused tests and verify GREEN**

Run: `flutter test test/game_world_renderer_source_test.dart test/game_map_renderer_test.dart test/game_building_style_test.dart -r compact`

Expected: all focused tests pass.

- [ ] **Step 6: Commit**

```bash
git add lib/features/game_home/presentation/game_map_renderer.dart test/game_world_renderer_source_test.dart test/game_map_renderer_test.dart
git commit -m "Render coastline depth and 2.5D buildings"
```

### Task 5: End-To-End Visual And Release Verification

**Files:**
- Modify only if verification exposes a defect in files from Tasks 1-4

**Interfaces:**
- Consumes: complete shared renderer and bundled terrain data
- Produces: verified Web build and Android release APK

- [ ] **Step 1: Run the full automated suite**

Run: `flutter test -r compact`

Expected: all tests pass.

- [ ] **Step 2: Run static analysis**

Run: `flutter analyze`

Expected: `No issues found!`

- [ ] **Step 3: Build both release targets**

Run: `flutter build web --release`

Run: `flutter build apk --release`

Expected: `build/web` and `build/app/outputs/flutter-apk/app-release.apk` exist.

- [ ] **Step 4: Verify Web visual behaviour**

Launch a local Web server, inject or select Sha Tin and a Hong Kong waterfront coordinate, capture before/after bearing screenshots, and verify roads, coastline, buildings, player, and 3D fishing spots rotate as one world. Confirm no blank surface, square texture seams, console errors, or lagging gestures.

- [ ] **Step 5: Verify Android API35 behaviour**

Launch only `FisherGO_API35`, install the release APK, grant location, inject the same test coordinates, and capture before/after rotation. Tap the 3D fishing spot and confirm its detail card opens. Search logcat for `FATAL EXCEPTION` and `ANR in com.fishergo.app`; expect no matches.

- [ ] **Step 6: Final review and commit any verification fixes**

Run: `git diff --check` and inspect the complete diff. If verification required fixes, rerun the relevant focused test and commit with a precise message. Keep generated screenshots and browser artifacts out of Git.

