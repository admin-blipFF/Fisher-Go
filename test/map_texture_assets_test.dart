import 'dart:io';
import 'dart:typed_data';
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

  test('grass micro map texture has soft matching edges for tiling', () async {
    final bytes =
        File('assets/maps/textures/grass_micro_tile.jpg').readAsBytesSync();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final pixels = data!.buffer.asUint8List();

    final horizontalDelta = _averageEdgeDelta(
      pixels,
      width: image.width,
      height: image.height,
      firstEdge: _Edge.left,
      secondEdge: _Edge.right,
    );
    final verticalDelta = _averageEdgeDelta(
      pixels,
      width: image.width,
      height: image.height,
      firstEdge: _Edge.top,
      secondEdge: _Edge.bottom,
    );

    expect(horizontalDelta, lessThan(24));
    expect(verticalDelta, lessThan(24));
  });
}

enum _Edge { left, right, top, bottom }

double _averageEdgeDelta(
  Uint8List pixels, {
  required int width,
  required int height,
  required _Edge firstEdge,
  required _Edge secondEdge,
}) {
  final samples =
      firstEdge == _Edge.left || firstEdge == _Edge.right ? height : width;
  var total = 0.0;
  for (var i = 0; i < samples; i++) {
    final first = _pixelForEdge(
      pixels,
      width: width,
      height: height,
      edge: firstEdge,
      index: i,
    );
    final second = _pixelForEdge(
      pixels,
      width: width,
      height: height,
      edge: secondEdge,
      index: i,
    );
    total += ((first.r - second.r).abs() +
            (first.g - second.g).abs() +
            (first.b - second.b).abs()) /
        3;
  }
  return total / samples;
}

({int r, int g, int b}) _pixelForEdge(
  Uint8List pixels, {
  required int width,
  required int height,
  required _Edge edge,
  required int index,
}) {
  final x = switch (edge) {
    _Edge.left => 0,
    _Edge.right => width - 1,
    _Edge.top || _Edge.bottom => index,
  };
  final y = switch (edge) {
    _Edge.left || _Edge.right => index,
    _Edge.top => 0,
    _Edge.bottom => height - 1,
  };
  final offset = (y * width + x) * 4;
  return (r: pixels[offset], g: pixels[offset + 1], b: pixels[offset + 2]);
}
