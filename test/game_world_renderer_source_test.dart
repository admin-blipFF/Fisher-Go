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
    final pubspecSource = File('pubspec.yaml').readAsStringSync();

    expect(source, isNot(contains('fishergo_overworld_imagegen_v3.png')));
    expect(source, contains('GameMapRenderer'));
    expect(source, contains('GameMapCamera'));
    expect(source, contains('GameMapFeatureStore'));
    expect(source, contains('_mapBearingDegrees'));
    expect(source, contains('_RotateMapButton'));
    expect(
        source, contains('static const double _spotDisplayRadiusMeters = 500'));
    expect(source, isNot(contains('_minVisibleSpots')));
    expect(source, isNot(contains('sorted.take')));
    expect(source, isNot(contains('spotCount.clamp(3, 7)')));
    expect(source, contains('_rotateMapByDrag'));
    expect(source, contains('onHorizontalDragUpdate'));
    expect(source, contains('visibleVectorFeatures'));
    expect(source, contains('terrainDataSource.buildTiles'));
    expect(source, contains('terrainTiles: terrainTiles'));
    expect(source, contains('onSpotSelected'));
    expect(source, contains('_buildProjectedSpotButtons'));
    expect(source, contains('_projectedSpotLiftPixels'));
    expect(source, contains('_developerTestSpots'));
    expect(source, contains('沙田希爾頓中心測試釣點'));
    expect(source, isNot(contains('Map<String, String> get _equipped => {}')));
    expect(source, contains('_loadAvatarSnapshot'));
    expect(source, contains('_MapAvatarSnapshot'));
    expect(source, contains('avatar_state'));
    expect(source, contains('AvatarLayeredPreview'));
    expect(source, contains('_SpotMarkerHalo'));
    expect(source, contains('_SpotMarkerBuoy'));
    expect(source, contains('_SpotMarkerDepthShadow'));
    expect(source, contains('Icons.phishing'));
    expect(source, contains("'assets/fishing/scenes/island.png'"));
    expect(source, contains("'assets/fishing/scenes/pier.png'"));
    expect(pubspecSource, contains('assets/fishing/scenes/'));
    expect(source, isNot(contains('_HybridTerrainMapPainter')));
    expect(rendererSource, contains('class GameMapPainter'));
    expect(rendererSource, contains('GameMapTexturePack'));
    expect(rendererSource, contains('assets/maps/textures/water_tile.jpg'));
    expect(rendererSource, contains('assets/maps/textures/land_tile.jpg'));
    expect(rendererSource, contains('assets/maps/textures/shore_tile.jpg'));
    expect(rendererSource, contains('assets/maps/textures/road_tile.jpg'));
    expect(rendererSource, contains('ImageShader'));
    expect(pubspecSource, contains('assets/maps/textures/'));
    expect(rendererSource, contains('_drawFallbackTileLayer'));
    expect(rendererSource, isNot(contains('_drawFallbackNode')));
    expect(rendererSource, contains('_drawSeaLayer'));
    expect(rendererSource, contains('_drawLandLayer'));
    expect(rendererSource, contains('_drawCoastlineLayer'));
    expect(rendererSource, contains('_drawRoadLayer'));
    expect(rendererSource, contains('_drawPierLayer'));
    expect(rendererSource, contains('_drawLandmarkLabelLayer'));
    expect(rendererSource, contains('_drawFishingSpotLayer'));
    expect(rendererSource, contains('_drawAtmosphereLayer'));
    expect(rendererSource, contains('_labelForFeature'));
    expect(rendererSource, contains('_fallbackLabelForTile'));
    expect(rendererSource, contains('_iconForFeature'));
    expect(source, isNot(contains('_drawFishingBeacons')));
    expect(source, isNot(contains('spotCount.clamp(0, 7)')));
  });
}
