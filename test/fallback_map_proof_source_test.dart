import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('vector fallback proof uses the GPS terrain dataset and 500m camera',
      () {
    final entrypoint = File('lib/map_fallback_proof_main.dart');
    final renderer = File(
      'lib/features/map/presentation/vector_map_fallback.dart',
    );
    expect(entrypoint.existsSync(), isTrue);
    expect(renderer.existsSync(), isTrue);

    final source = entrypoint.readAsStringSync();
    final rendererSource = renderer.readAsStringSync();
    expect(source, contains("assets/maps/hk_terrain_mvp.json"));
    expect(source, contains('GeoTerrainDataset.fromJson'));
    expect(source, contains('GeoTerrainDataSource'));
    expect(source, contains('GameMapFeatureStore'));
    expect(source, contains('GameMapCamera'));
    expect(source, contains('visibleRadiusMeters: 500'));
    expect(source, contains('vector_map_fallback.dart'));
    expect(rendererSource, contains('OptimizedVectorMapPainter'));
    expect(rendererSource, contains('roadGroups'));
    expect(rendererSource, contains('VectorFallbackBackgroundPainter'));
    expect(source, contains('onHorizontalDragUpdate'));
    expect(source, contains('projectFishingSpots'));
    expect(source, contains('MapPerformanceMonitor'));
    expect(source, contains('FisherGO fallback performance'));
    expect(source, contains('_performanceReporter.shouldReport'));
  });
}
