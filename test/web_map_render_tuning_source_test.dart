import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Web MapLibre tuning preserves real map options', () {
    final source = File('web/maplibre_render_tuning.js').readAsStringSync();
    final index = File('web/index.html').readAsStringSync();

    expect(source, contains('crossSourceCollisions: false'));
    expect(source, contains('fadeDuration: 0'));
    expect(source, contains('refreshExpiredTiles: false'));
    expect(source, contains('renderWorldCopies: false'));
    expect(source, contains('reparseOverscaled: false'));
    expect(source, contains('fishergo_desynchronized'));
    expect(source, contains('desynchronized: true'));
    expect(source, contains('canvasContextAttributes'));
    expect(source, contains('fishergo_road_simplify'));
    expect(source, contains('road-minor-casing'));
    expect(source, contains('road-path'));
    expect(source, contains('fishergo_web_no_extrusion'));
    expect(source, contains("layer.id !== 'building-3d'"));
    expect(source, contains('fishergo_pixel_ratio'));
    expect(source, contains('requestedPixelRatioRaw === null'));
    expect(source, contains('options.pixelRatio'));
    expect(source, contains('window.innerWidth'));
    expect(source, contains('devicePixelRatio'));
    expect(source, contains('fishergo_tile_cache_levels'));
    expect(source, contains('maxTileCacheZoomLevels'));
    expect(source, contains('__FISHERGO_TILE_CACHE_LEVELS__'));
    expect(source, contains('Reflect.construct'));
    expect(source, contains('__FISHERGO_MAP_RENDER_TUNING_APPLIED__'));
    expect(index, contains('maplibre_render_tuning.js'));
  });
}
