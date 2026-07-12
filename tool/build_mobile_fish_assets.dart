import 'dart:io';

import 'package:image/image.dart' as image;

const sourcePath = 'assets/fish/icons/generated';
const outputPath = 'assets/fish/mobile';
const maxDimension = 384;

Future<void> main() async {
  final source = Directory(sourcePath);
  final output = Directory(outputPath);
  if (!source.existsSync()) {
    throw StateError('Missing source directory: $sourcePath');
  }
  await output.create(recursive: true);

  var written = 0;
  var skipped = 0;
  await for (final entity in source.list(followLinks: false)) {
    if (entity is! File || !entity.path.toLowerCase().endsWith('.png')) {
      continue;
    }
    final decoded = image.decodePng(await entity.readAsBytes());
    if (decoded == null) {
      skipped++;
      continue;
    }
    final longest =
        decoded.width > decoded.height ? decoded.width : decoded.height;
    final scale = longest > maxDimension ? maxDimension / longest : 1.0;
    final resized = scale < 1
        ? image.copyResize(
            decoded,
            width: (decoded.width * scale).round(),
            height: (decoded.height * scale).round(),
            interpolation: image.Interpolation.average,
          )
        : decoded;
    final destination = File(
      '${output.path}${Platform.pathSeparator}${entity.uri.pathSegments.last}',
    );
    await destination.writeAsBytes(image.encodePng(resized, level: 7));
    written++;
  }
  stdout.writeln('Wrote $written mobile fish assets; skipped $skipped.');
}
