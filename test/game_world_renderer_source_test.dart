import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'game world uses GPS terrain renderer instead of a fixed background image',
      () {
    final source = File(
      'lib/features/game_home/presentation/game_home_screen.dart',
    ).readAsStringSync();
    final rendererSource = File(
      'lib/features/game_home/presentation/game_map_renderer.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('fishergo_overworld_imagegen_v3.png')));
    expect(source, contains('GameMapRenderer'));
    expect(source, contains('GameMapCamera'));
    expect(source, contains('GameMapFeatureStore'));
    expect(source, contains('_mapBearingDegrees'));
    expect(source, contains('_RotateMapButton'));
    expect(source, contains('visibleVectorFeatures'));
    expect(source, isNot(contains('_HybridTerrainMapPainter')));
    expect(rendererSource, contains('class GameMapPainter'));
    expect(rendererSource, contains('_drawSeaLayer'));
    expect(rendererSource, contains('_drawLandLayer'));
    expect(rendererSource, contains('_drawCoastlineLayer'));
    expect(rendererSource, contains('_drawRoadLayer'));
    expect(rendererSource, contains('_drawPierLayer'));
    expect(rendererSource, contains('_drawFishingSpotLayer'));
    expect(rendererSource, contains('_drawAtmosphereLayer'));
  });
}
