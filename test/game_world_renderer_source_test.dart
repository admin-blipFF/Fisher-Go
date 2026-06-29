import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'game world uses GPS terrain renderer instead of a fixed background image',
      () {
    final source = File(
      'lib/features/game_home/presentation/game_home_screen.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('fishergo_overworld_imagegen_v3.png')));
    expect(source, contains('_HybridTerrainMapPainter'));
    expect(source, contains('_mapBearingDegrees'));
    expect(source, contains('_RotateMapButton'));
    expect(source, contains('_drawTerrainVectorOverlays'));
    expect(source, contains('visibleVectorFeatures'));
    expect(source, contains('_drawTileRoadNetwork'));
    expect(source, contains('_drawTileCoastlineNetwork'));
  });
}
