# Pokemon GO Map Engine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a shared FisherGO game map engine that renders a GPS-centered, rotatable, visually coherent Pokemon GO-style fishing map on web and Android APK.

**Architecture:** Introduce a small map engine under `lib/features/game_home/domain/` and `lib/features/game_home/presentation/` instead of continuing to grow `_HybridTerrainMapPainter`. The engine has a `GameMapCamera` for projection/bearing, a `GameMapFeatureStore` for terrain and fishing spot geometry, and a renderer shell that consumes projected geometry. Existing `GameHomeScreen` remains the orchestrator for GPS, spot selection, tutorial, and fishing flow.

**Tech Stack:** Flutter, Dart, `latlong2`, existing `flutter_test`, bundled JSON terrain assets, existing `flutter_map` panoramic map, Android Gradle build.

---

## File Structure

- Create: `lib/features/game_home/domain/game_map_camera.dart`
  - Owns center GPS, visible radius, bearing, viewport size, and projection math.
- Create: `test/game_map_camera_test.dart`
  - Verifies center projection, bearing rotation, and distance scale.
- Create: `lib/features/game_home/domain/game_map_feature_store.dart`
  - Wraps `GeoTerrainDataset`, visible terrain vectors, and fishing spots into renderer-ready game-map features.
- Create: `test/game_map_feature_store_test.dart`
  - Verifies visible terrain geometry and fishing spot projection source.
- Create: `lib/features/game_home/presentation/game_map_renderer.dart`
  - Holds focused painter/rendering classes for water, land, roads, piers, fishing spot markers, and atmosphere.
- Modify: `lib/features/game_home/presentation/game_home_screen.dart`
  - Replace most of `_HybridTerrainMapPainter` internals with the new renderer, keep HUD, controls, panoramic map, and fishing flow.
- Modify: `test/game_world_renderer_source_test.dart`
  - Assert the home screen uses the new engine and keeps the panoramic map path.
- Modify: `test/terrain_data_source_test.dart`
  - Keep existing regression coverage for bundled terrain parsing.
- Optional if Android SDK is configured: Android build artifacts under `build/app/outputs/flutter-apk/`.

---

## Task 1: Game Map Camera

**Files:**
- Create: `lib/features/game_home/domain/game_map_camera.dart`
- Create: `test/game_map_camera_test.dart`

- [ ] **Step 1: Write failing camera tests**

Create `test/game_map_camera_test.dart`:

```dart
import 'dart:ui';

import 'package:fishergo/features/game_home/domain/game_map_camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('GameMapCamera', () {
    test('projects center GPS to viewport center', () {
      final camera = GameMapCamera(
        center: const LatLng(22.3517, 114.0743),
        visibleRadiusMeters: 500,
        bearingDegrees: 0,
        viewportSize: const Size(390, 844),
      );

      final projected = camera.project(const LatLng(22.3517, 114.0743));

      expect(projected.dx, closeTo(195, 0.01));
      expect(projected.dy, closeTo(422, 0.01));
    });

    test('projects north point above center with zero bearing', () {
      final camera = GameMapCamera(
        center: const LatLng(22.3517, 114.0743),
        visibleRadiusMeters: 500,
        bearingDegrees: 0,
        viewportSize: const Size(390, 844),
      );

      final projected = camera.project(const LatLng(22.3562, 114.0743));

      expect(projected.dx, closeTo(195, 1));
      expect(projected.dy, lessThan(422));
    });

    test('bearing rotates projected points around center', () {
      final camera = GameMapCamera(
        center: const LatLng(22.3517, 114.0743),
        visibleRadiusMeters: 500,
        bearingDegrees: 90,
        viewportSize: const Size(390, 844),
      );

      final projected = camera.project(const LatLng(22.3562, 114.0743));

      expect(projected.dx, greaterThan(195));
      expect(projected.dy, closeTo(422, 8));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```powershell
C:\Users\s0829\tools\flutter\bin\flutter.bat test test\game_map_camera_test.dart
```

Expected: FAIL because `game_map_camera.dart` does not exist.

- [ ] **Step 3: Implement `GameMapCamera`**

Create `lib/features/game_home/domain/game_map_camera.dart`:

```dart
import 'dart:math' as math;
import 'dart:ui';

import 'package:latlong2/latlong.dart';

class GameMapCamera {
  const GameMapCamera({
    required this.center,
    required this.visibleRadiusMeters,
    required this.bearingDegrees,
    required this.viewportSize,
  });

  final LatLng center;
  final double visibleRadiusMeters;
  final double bearingDegrees;
  final Size viewportSize;

  Offset get viewportCenter =>
      Offset(viewportSize.width * 0.5, viewportSize.height * 0.5);

  Offset project(LatLng point) {
    final meters = _metersFromCenter(point);
    final rotated = _rotate(meters, bearingDegrees);
    final pixelsPerMeter = _pixelsPerMeter;
    return Offset(
      viewportCenter.dx + rotated.dx * pixelsPerMeter,
      viewportCenter.dy - rotated.dy * pixelsPerMeter,
    );
  }

  bool isVisible(LatLng point, {double paddingMeters = 120}) {
    return _metersFromCenter(point).distance <=
        visibleRadiusMeters + paddingMeters;
  }

  double get _pixelsPerMeter =>
      math.min(viewportSize.width, viewportSize.height) /
      (visibleRadiusMeters * 2);

  Offset _metersFromCenter(LatLng point) {
    const metersPerDegreeLat = 111320.0;
    final metersPerDegreeLng =
        111320.0 * math.cos(center.latitude * math.pi / 180);
    return Offset(
      (point.longitude - center.longitude) * metersPerDegreeLng,
      (point.latitude - center.latitude) * metersPerDegreeLat,
    );
  }

  Offset _rotate(Offset meters, double degrees) {
    final radians = degrees * math.pi / 180;
    final cosA = math.cos(radians);
    final sinA = math.sin(radians);
    return Offset(
      meters.dx * cosA + meters.dy * sinA,
      -meters.dx * sinA + meters.dy * cosA,
    );
  }
}
```

- [ ] **Step 4: Verify camera tests pass**

Run:

```powershell
C:\Users\s0829\tools\flutter\bin\flutter.bat test test\game_map_camera_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add lib\features\game_home\domain\game_map_camera.dart test\game_map_camera_test.dart
git commit -m "Add game map camera projection"
```

---

## Task 2: Game Map Feature Store

**Files:**
- Create: `lib/features/game_home/domain/game_map_feature_store.dart`
- Create: `test/game_map_feature_store_test.dart`
- Modify: `lib/features/game_home/domain/terrain_data_source.dart` only if shared data types need small additions.

- [ ] **Step 1: Write failing feature store tests**

Create `test/game_map_feature_store_test.dart`:

```dart
import 'dart:io';

import 'package:fishergo/features/game_home/domain/game_map_camera.dart';
import 'package:fishergo/features/game_home/domain/game_map_feature_store.dart';
import 'package:fishergo/features/game_home/domain/terrain_data_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test('exposes visible terrain vectors around Tsing Ma', () {
    final dataset = GeoTerrainDataset.fromJson(
      File('assets/maps/hk_terrain_mvp.json').readAsStringSync(),
    );
    final store = GameMapFeatureStore(dataset: dataset);
    final camera = GameMapCamera(
      center: const LatLng(22.3517, 114.0743),
      visibleRadiusMeters: 500,
      bearingDegrees: 0,
      viewportSize: const Size(390, 844),
    );

    final features = store.visibleTerrainFeatures(camera);

    expect(features.map((feature) => feature.kind), contains(TerrainKind.road));
    expect(features.map((feature) => feature.kind), contains(TerrainKind.water));
    expect(features.every((feature) => feature.points.length >= 2), isTrue);
  });

  test('projects fishing spots through the same camera', () {
    final store = GameMapFeatureStore(dataset: const GeoTerrainDataset(features: []));
    final camera = GameMapCamera(
      center: const LatLng(22.3517, 114.0743),
      visibleRadiusMeters: 500,
      bearingDegrees: 0,
      viewportSize: const Size(390, 844),
    );

    final markers = store.projectFishingSpots(
      camera: camera,
      spots: const [
        GameMapFishingSpot(
          id: 'tsing-ma-test',
          name: '青馬測試釣點',
          position: LatLng(22.3517, 114.0743),
        ),
      ],
    );

    expect(markers.single.id, 'tsing-ma-test');
    expect(markers.single.screenPosition.dx, closeTo(195, 0.01));
    expect(markers.single.screenPosition.dy, closeTo(422, 0.01));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```powershell
C:\Users\s0829\tools\flutter\bin\flutter.bat test test\game_map_feature_store_test.dart
```

Expected: FAIL because `game_map_feature_store.dart` does not exist.

- [ ] **Step 3: Implement feature store**

Create `lib/features/game_home/domain/game_map_feature_store.dart`:

```dart
import 'dart:ui';

import 'package:latlong2/latlong.dart';

import 'game_map_camera.dart';
import 'terrain_data_source.dart';

class GameMapFishingSpot {
  const GameMapFishingSpot({
    required this.id,
    required this.name,
    required this.position,
  });

  final String id;
  final String name;
  final LatLng position;
}

class ProjectedFishingSpot {
  const ProjectedFishingSpot({
    required this.id,
    required this.name,
    required this.position,
    required this.screenPosition,
  });

  final String id;
  final String name;
  final LatLng position;
  final Offset screenPosition;
}

class GameMapFeatureStore {
  const GameMapFeatureStore({required this.dataset});

  final GeoTerrainDataset dataset;

  List<TerrainVectorFeature> visibleTerrainFeatures(GameMapCamera camera) {
    return [
      for (final feature in dataset.features)
        if (_isVisibleGeometry(feature, camera))
          TerrainVectorFeature(
            kind: feature.kind,
            name: feature.name,
            points: feature.geometry!.coordinates,
            isClosed: feature.geometry!.isPolygon,
          ),
    ];
  }

  List<ProjectedFishingSpot> projectFishingSpots({
    required GameMapCamera camera,
    required List<GameMapFishingSpot> spots,
  }) {
    return [
      for (final spot in spots)
        if (camera.isVisible(spot.position))
          ProjectedFishingSpot(
            id: spot.id,
            name: spot.name,
            position: spot.position,
            screenPosition: camera.project(spot.position),
          ),
    ];
  }

  bool _isVisibleGeometry(GeoTerrainFeature feature, GameMapCamera camera) {
    final geometry = feature.geometry;
    if (geometry == null || geometry.coordinates.length < 2) return false;
    if (feature.kind == TerrainKind.fishingNode) return false;
    return geometry.coordinates.any(camera.isVisible) ||
        camera.isVisible(feature.center, paddingMeters: feature.radiusMeters);
  }
}
```

- [ ] **Step 4: Verify feature store tests pass**

```powershell
C:\Users\s0829\tools\flutter\bin\flutter.bat test test\game_map_feature_store_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add lib\features\game_home\domain\game_map_feature_store.dart test\game_map_feature_store_test.dart
git commit -m "Add game map feature store"
```

---

## Task 3: Renderer Extraction

**Files:**
- Create: `lib/features/game_home/presentation/game_map_renderer.dart`
- Modify: `lib/features/game_home/presentation/game_home_screen.dart`
- Modify: `test/game_world_renderer_source_test.dart`

- [ ] **Step 1: Write failing source regression test**

Modify `test/game_world_renderer_source_test.dart` to require the extracted renderer:

```dart
expect(source, contains('GameMapRenderer'));
expect(source, contains('GameMapCamera'));
expect(source, contains('GameMapFeatureStore'));
expect(source, isNot(contains('fishergo_overworld_imagegen_v3.png')));
```

- [ ] **Step 2: Run test to verify it fails**

```powershell
C:\Users\s0829\tools\flutter\bin\flutter.bat test test\game_world_renderer_source_test.dart
```

Expected: FAIL because `GameMapRenderer` is not wired into the home screen.

- [ ] **Step 3: Create renderer shell**

Create `lib/features/game_home/presentation/game_map_renderer.dart` with:

```dart
import 'package:flutter/material.dart';

import '../domain/game_map_camera.dart';
import '../domain/game_map_feature_store.dart';
import '../domain/terrain_data_source.dart';

class GameMapRenderer extends StatelessWidget {
  const GameMapRenderer({
    super.key,
    required this.camera,
    required this.terrainFeatures,
    required this.fishingSpots,
  });

  final GameMapCamera camera;
  final List<TerrainVectorFeature> terrainFeatures;
  final List<ProjectedFishingSpot> fishingSpots;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: GameMapPainter(
        camera: camera,
        terrainFeatures: terrainFeatures,
        fishingSpots: fishingSpots,
      ),
      size: Size.infinite,
    );
  }
}
```

Then move or recreate the existing map drawing code inside `GameMapPainter`, using `camera.project(point)` for vector and spot geometry. Keep a simple fallback texture for areas without enough vector data.

- [ ] **Step 4: Wire home screen**

In `lib/features/game_home/presentation/game_home_screen.dart`:

- import `game_map_camera.dart`
- import `game_map_feature_store.dart`
- import `game_map_renderer.dart`
- create `GameMapCamera` inside `_GameWorldMapShell.build`
- create `GameMapFeatureStore` from the loaded `GeoTerrainDataset` or expose it through the existing `TerrainDataSource`
- render `GameMapRenderer` as the background layer

Keep `_PanoramaMapSheet`, `_RotateMapButton`, `_LocateButton`, `_SideButtons`, `_BottomBar`, and fishing callbacks unchanged.

- [ ] **Step 5: Verify renderer source test passes**

```powershell
C:\Users\s0829\tools\flutter\bin\flutter.bat test test\game_world_renderer_source_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

```powershell
git add lib\features\game_home\presentation\game_map_renderer.dart lib\features\game_home\presentation\game_home_screen.dart test\game_world_renderer_source_test.dart
git commit -m "Extract game map renderer"
```

---

## Task 4: Accurate Fishing Spot Projection

**Files:**
- Modify: `lib/features/game_home/presentation/game_home_screen.dart`
- Modify: `lib/features/game_home/domain/game_map_feature_store.dart`
- Test: `test/game_map_feature_store_test.dart`

- [ ] **Step 1: Add failing test for off-center fishing spot**

Extend `test/game_map_feature_store_test.dart`:

```dart
test('keeps east fishing spot to the right after projection', () {
  final store = GameMapFeatureStore(dataset: const GeoTerrainDataset(features: []));
  final camera = GameMapCamera(
    center: const LatLng(22.3517, 114.0743),
    visibleRadiusMeters: 500,
    bearingDegrees: 0,
    viewportSize: const Size(390, 844),
  );

  final markers = store.projectFishingSpots(
    camera: camera,
    spots: const [
      GameMapFishingSpot(
        id: 'east',
        name: '東面釣點',
        position: LatLng(22.3517, 114.0783),
      ),
    ],
  );

  expect(markers.single.screenPosition.dx, greaterThan(195));
});
```

- [ ] **Step 2: Run test to verify it fails or passes for the right reason**

```powershell
C:\Users\s0829\tools\flutter\bin\flutter.bat test test\game_map_feature_store_test.dart
```

If it already passes, add a bearing version:

```dart
test('bearing rotates fishing spot with terrain camera', () {
  final store = GameMapFeatureStore(dataset: const GeoTerrainDataset(features: []));
  final camera = GameMapCamera(
    center: const LatLng(22.3517, 114.0743),
    visibleRadiusMeters: 500,
    bearingDegrees: 90,
    viewportSize: const Size(390, 844),
  );

  final markers = store.projectFishingSpots(
    camera: camera,
    spots: const [
      GameMapFishingSpot(
        id: 'north',
        name: '北面釣點',
        position: LatLng(22.3562, 114.0743),
      ),
    ],
  );

  expect(markers.single.screenPosition.dx, greaterThan(195));
});
```

- [ ] **Step 3: Wire `_visibleSpots` into `GameMapFishingSpot`**

In `game_home_screen.dart`, convert `_SpotDemo` to `GameMapFishingSpot`:

```dart
final gameMapSpots = [
  for (final spot in spots)
    GameMapFishingSpot(
      id: spot.name,
      name: spot.name,
      position: LatLng(spot.lat, spot.lng),
    ),
];
```

Pass projected markers to `GameMapRenderer`. Do not use `projectFishingNodes()` for visible real fishing spots.

- [ ] **Step 4: Verify tests**

```powershell
C:\Users\s0829\tools\flutter\bin\flutter.bat test test\game_map_feature_store_test.dart test\game_world_renderer_source_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add lib\features\game_home\presentation\game_home_screen.dart lib\features\game_home\domain\game_map_feature_store.dart test\game_map_feature_store_test.dart
git commit -m "Project fishing spots through game map camera"
```

---

## Task 5: Visual Polish Pass

**Files:**
- Modify: `lib/features/game_home/presentation/game_map_renderer.dart`
- Modify: `lib/features/game_home/presentation/game_home_screen.dart` only for control spacing if needed.

- [ ] **Step 1: Add visual source assertions**

In `test/game_world_renderer_source_test.dart`, assert the renderer has named layer methods:

```dart
expect(source, contains('_drawSeaLayer'));
expect(source, contains('_drawLandLayer'));
expect(source, contains('_drawRoadLayer'));
expect(source, contains('_drawFishingSpotLayer'));
expect(source, contains('_drawAtmosphereLayer'));
```

- [ ] **Step 2: Run source test to verify it fails**

```powershell
C:\Users\s0829\tools\flutter\bin\flutter.bat test test\game_world_renderer_source_test.dart
```

Expected: FAIL until named layers exist.

- [ ] **Step 3: Implement named visual layers**

In `game_map_renderer.dart`, implement layers with this order:

```dart
@override
void paint(Canvas canvas, Size size) {
  _drawSeaLayer(canvas, size);
  _drawLandLayer(canvas, size);
  _drawCoastlineLayer(canvas, size);
  _drawRoadLayer(canvas, size);
  _drawPierLayer(canvas, size);
  _drawFishingSpotLayer(canvas, size);
  _drawAtmosphereLayer(canvas, size);
}
```

Use restrained colors:

- sea base: cyan/teal with subtle wave strokes
- land: green with low-opacity texture
- coastline: pale foam stroke plus darker edge
- roads: dark edge, warm yellow road fill, white highlight
- piers/bridges: wood/stone strokes
- fishing spots: glow circle, pin core, distance ring

Avoid filling the screen with repeated visible grid strokes.

- [ ] **Step 4: Build web and capture screenshot**

```powershell
C:\Users\s0829\tools\flutter\bin\flutter.bat build web --release
npx serve@14.2.5 build\web -l 56363
npx playwright screenshot --channel=msedge --block-service-workers --wait-for-timeout=12000 --viewport-size=390,844 http://localhost:56363 C:\Users\s0829\fishergo\tmp-game-map-engine.png
```

Inspect:

```powershell
# Stop server after screenshot
$conn = Get-NetTCPConnection -LocalPort 56363 -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1; if ($conn) { Stop-Process -Id $conn.OwningProcess -Force }
```

Expected: screenshot shows a coherent game map with continuous lines and readable fishing spot markers.

- [ ] **Step 5: Commit**

```powershell
git add lib\features\game_home\presentation\game_map_renderer.dart lib\features\game_home\presentation\game_home_screen.dart test\game_world_renderer_source_test.dart
git commit -m "Polish game map visual layers"
```

---

## Task 6: Full Verification And Android APK

**Files:**
- No planned source changes unless verification exposes issues.

- [ ] **Step 1: Run analyzer**

```powershell
C:\Users\s0829\tools\flutter\bin\flutter.bat analyze
```

Expected: `No issues found!`

- [ ] **Step 2: Run full tests**

```powershell
C:\Users\s0829\tools\flutter\bin\flutter.bat test
```

Expected: all tests pass.

- [ ] **Step 3: Build web release**

```powershell
C:\Users\s0829\tools\flutter\bin\flutter.bat build web --release
```

Expected: `Built build\web`.

- [ ] **Step 4: Build Android APK**

```powershell
C:\Users\s0829\tools\flutter\bin\flutter.bat build apk --debug
```

Expected: APK exists at:

```text
build\app\outputs\flutter-apk\app-debug.apk
```

If Android SDK is not configured, capture the exact `flutter doctor -v` output and install/configure SDK before claiming completion.

- [ ] **Step 5: Optional emulator smoke if available**

```powershell
$adb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
& $adb devices
& $adb install -r build\app\outputs\flutter-apk\app-debug.apk
& $adb shell monkey -p com.fishergo.app 1
Start-Sleep -Seconds 10
& $adb logcat -d -t 3000 | Select-String -Pattern 'FATAL EXCEPTION|AndroidRuntime.*com\.fishergo|E/flutter|Unable to load asset|permission|flutter_map'
```

Expected: no fatal app crashes or missing asset errors.

- [ ] **Step 6: Deploy web and alias domains**

After pushing the implementation branch:

```powershell
$deployments = npx vercel@54.17.1 ls fishergo --scope klyeung-s-projects
$deployments
$deploymentUrl = ($deployments | Select-String 'https://fishergo-.*\.vercel\.app' | Select-Object -First 1).Matches.Value
$inspect = npx vercel@54.17.1 inspect $deploymentUrl --scope klyeung-s-projects
$inspect
if ($inspect -notmatch 'status\s+.*Ready') { throw "Latest deployment is not Ready yet. Wait and rerun this block." }
npx vercel@54.17.1 alias set $deploymentUrl fisher-go.app --scope klyeung-s-projects
npx vercel@54.17.1 alias set $deploymentUrl www.fisher-go.app --scope klyeung-s-projects
curl.exe -I https://www.fisher-go.app
```

Expected: the guard stops before aliasing unless `inspect` reports a Ready deployment.

Expected: `https://www.fisher-go.app` returns `200 OK`.

- [ ] **Step 7: Final commit if verification fixes were needed**

```powershell
git status --short
git add lib\features\game_home docs\superpowers test
git commit -m "Verify game map engine across web and Android"
```

Only commit if files changed during verification.

---

## Self-Review

- Spec coverage: camera, bearing, real spot projection, feature store, renderer layers, web build, Android APK build, and live web deployment are covered.
- Placeholder scan: no TBD/TODO placeholders are used as plan steps.
- Type consistency: `GameMapCamera`, `GameMapFeatureStore`, `GameMapFishingSpot`, `ProjectedFishingSpot`, `TerrainVectorFeature`, and `GameMapRenderer` are introduced before use.
- Scope: this is Phase 1 of the full map-system goal. It does not claim full Hong Kong OSM coverage, paid 3D maps, compass auto-heading, or emulator smoke if no Android runtime is available.
