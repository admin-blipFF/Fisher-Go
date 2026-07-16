import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as image;

const _targetSize = 1024;
const _edgeBlendWidth = 96;

Future<void> main(List<String> arguments) async {
  if (arguments.length != 2) {
    stderr.writeln(
      'Usage: dart run tool/prepare_seamless_texture.dart <input> <output>',
    );
    exitCode = 64;
    return;
  }

  final source = File(arguments[0]);
  if (!source.existsSync()) {
    throw StateError('Missing texture source: ${source.path}');
  }
  final decoded = image.decodeImage(await source.readAsBytes());
  if (decoded == null) {
    throw StateError('Unable to decode texture: ${source.path}');
  }

  final squareSize = math.min(decoded.width, decoded.height);
  final square = image.copyCrop(
    decoded,
    x: (decoded.width - squareSize) ~/ 2,
    y: (decoded.height - squareSize) ~/ 2,
    width: squareSize,
    height: squareSize,
  );
  final prepared = image.copyResize(
    square,
    width: _targetSize,
    height: _targetSize,
    interpolation: image.Interpolation.average,
  );

  _blendHorizontalEdges(prepared, _edgeBlendWidth);
  _blendVerticalEdges(prepared, _edgeBlendWidth);

  final destination = File(arguments[1]);
  await destination.parent.create(recursive: true);
  await destination.writeAsBytes(image.encodeJpg(prepared, quality: 88));
  stdout.writeln(
    'Prepared ${destination.path}: ${prepared.width}x${prepared.height}',
  );
}

void _blendHorizontalEdges(image.Image texture, int blendWidth) {
  final width = math.min(blendWidth, texture.width ~/ 2);
  for (var y = 0; y < texture.height; y++) {
    for (var x = 0; x < width; x++) {
      final oppositeX = texture.width - 1 - x;
      final left = texture.getPixel(x, y);
      final right = texture.getPixel(oppositeX, y);
      final edgeMix = _smoothstep(x / (width - 1));
      _writeBlendedPair(
        texture,
        firstX: x,
        firstY: y,
        secondX: oppositeX,
        secondY: y,
        first: left,
        second: right,
        edgeMix: edgeMix,
      );
    }
  }
}

void _blendVerticalEdges(image.Image texture, int blendWidth) {
  final height = math.min(blendWidth, texture.height ~/ 2);
  for (var x = 0; x < texture.width; x++) {
    for (var y = 0; y < height; y++) {
      final oppositeY = texture.height - 1 - y;
      final top = texture.getPixel(x, y);
      final bottom = texture.getPixel(x, oppositeY);
      final edgeMix = _smoothstep(y / (height - 1));
      _writeBlendedPair(
        texture,
        firstX: x,
        firstY: y,
        secondX: x,
        secondY: oppositeY,
        first: top,
        second: bottom,
        edgeMix: edgeMix,
      );
    }
  }
}

void _writeBlendedPair(
  image.Image texture, {
  required int firstX,
  required int firstY,
  required int secondX,
  required int secondY,
  required image.Pixel first,
  required image.Pixel second,
  required double edgeMix,
}) {
  final averageR = (first.r + second.r) * 0.5;
  final averageG = (first.g + second.g) * 0.5;
  final averageB = (first.b + second.b) * 0.5;
  texture.setPixelRgb(
    firstX,
    firstY,
    _lerp(averageR, first.r, edgeMix),
    _lerp(averageG, first.g, edgeMix),
    _lerp(averageB, first.b, edgeMix),
  );
  texture.setPixelRgb(
    secondX,
    secondY,
    _lerp(averageR, second.r, edgeMix),
    _lerp(averageG, second.g, edgeMix),
    _lerp(averageB, second.b, edgeMix),
  );
}

double _smoothstep(double value) => value * value * (3 - 2 * value);

num _lerp(num start, num end, double amount) =>
    start + (end - start) * amount;
