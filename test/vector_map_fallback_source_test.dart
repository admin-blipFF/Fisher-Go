import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('vector fallback is a shared opt-in production renderer', () {
    final renderer = File(
      'lib/features/map/presentation/vector_map_fallback.dart',
    );
    final config = File('lib/core/config/public_app_config.dart');
    final gameHome = File(
      'lib/features/game_home/presentation/game_home_screen.dart',
    );

    expect(renderer.existsSync(), isTrue);
    expect(renderer.readAsStringSync(),
        contains('class OptimizedVectorMapPainter'));
    expect(renderer.readAsStringSync(),
        contains('class VectorFallbackBackgroundPainter'));
    expect(
        renderer.readAsStringSync(), contains('class VectorFallbackSurface'));
    expect(renderer.readAsStringSync(), contains('water_tile_v2.jpg'));
    expect(renderer.readAsStringSync(), contains('grass_micro_tile.jpg'));
    expect(renderer.readAsStringSync(),
        contains('VectorFallbackPerformanceProbe'));
    expect(
        renderer.readAsStringSync(), contains('FisherGO fallback performance'));
    expect(renderer.readAsStringSync(),
        contains('_reporter.shouldReport(_frameCount)'));
    expect(renderer.readAsStringSync(), contains('TextPainter'));
    expect(
        renderer.readAsStringSync(), contains('clusterProjectedFishingSpots'));
    expect(renderer.readAsStringSync(),
        contains('_geometrySimplificationToleranceSquared'));
    expect(renderer.readAsStringSync(),
        contains('_motionGeometrySimplificationToleranceSquared'));
    expect(renderer.readAsStringSync(), contains('= 4.0;'));
    expect(renderer.readAsStringSync(),
        contains('_appendSimplifiedProjectedPoints'));
    expect(
        renderer.readAsStringSync(),
        contains(
            '_drawHydroAndLand(canvas, waterPaint, landPaint, shorePaint)'));
    expect(renderer.readAsStringSync(), contains('_drawMotionHydroAndLand'));
    expect(renderer.readAsStringSync(), contains('texturesEnabled'));
    expect(renderer.readAsStringSync(),
        contains('if (!texturesEnabled) return false;'));
    expect(renderer.readAsStringSync(),
        contains('feature.kind != TerrainKind.water'));
    expect(gameHome.readAsStringSync(), contains('onTapUp'));
    expect(config.readAsStringSync(), contains('FISHERGO_MAP_VECTOR_FALLBACK'));
    expect(gameHome.readAsStringSync(), contains('mapVectorFallbackEnabled'));
    expect(gameHome.readAsStringSync(),
        isNot(contains('developerTestSpotsEnabled')));
    expect(renderer.readAsStringSync(), contains('OptimizedVectorMapPainter'));
    expect(renderer.readAsStringSync(), contains('return RepaintBoundary('));
    expect(gameHome.readAsStringSync(), contains('VectorFallbackSurface'));
    expect(gameHome.readAsStringSync(),
        contains('_buildVectorFallbackSpotButtons'));
    final homeSource = gameHome.readAsStringSync();
    final initStart = homeSource.indexOf('void initState()');
    final initEnd = homeSource.indexOf('Future<void> _loadAvatarSnapshot');
    expect(initStart, greaterThanOrEqualTo(0));
    expect(initEnd, greaterThan(initStart));
    expect(homeSource.substring(initStart, initEnd),
        isNot(contains('..repeat()')));
  });
}
