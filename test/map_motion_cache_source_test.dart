import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('classic map freezes the painter camera during bearing drags', () {
    final source = File(
      'lib/features/game_home/presentation/game_home_screen.dart',
    ).readAsStringSync();
    final shellSource = source.substring(
      source.indexOf('class _GameWorldMapShell'),
    );

    expect(shellSource, contains('camera: renderCamera'));
    expect(shellSource, contains('motionOptimized: isMapInteracting'));
    expect(shellSource, contains('RepaintBoundary'));
    expect(shellSource, contains('child: mapContent'));

    final rendererSource = File(
      'lib/features/game_home/presentation/game_map_renderer.dart',
    ).readAsStringSync();
    expect(rendererSource, contains('this.motionOptimized = false'));
    expect(rendererSource, contains('if (motionOptimized)'));
    expect(rendererSource, contains('_drawMotionMapSurface(canvas, size)'));
    expect(rendererSource, contains('_drawRoadLayer(canvas, size)'));
  });
}
