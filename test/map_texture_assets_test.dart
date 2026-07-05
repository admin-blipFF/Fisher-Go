import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('water map texture is a square tile asset', () async {
    final bytes = File('assets/maps/textures/water_tile.jpg').readAsBytesSync();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    expect(image.width, 1024);
    expect(image.height, 1024);
  });

  test('grass micro map texture is a square tile asset', () async {
    final bytes =
        File('assets/maps/textures/grass_micro_tile.jpg').readAsBytesSync();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    expect(image.width, 1024);
    expect(image.height, 1024);
  });
}
