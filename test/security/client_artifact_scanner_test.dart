import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_client_artifacts_for_secrets.dart';

void main() {
  test('finds a forbidden token split across scan chunks', () async {
    final directory = await Directory.systemTemp.createTemp('fishergo-scan-');
    addTearDown(() => directory.delete(recursive: true));

    const token = 'VECTOR_ENGINE_API_KEY';
    const splitAt = 8;
    final file = File('${directory.path}${Platform.pathSeparator}bundle.bin');
    final prefix = 'x' * (artifactScanChunkSize - splitAt);
    await file.writeAsString(
      prefix + token.substring(0, splitAt) + token.substring(splitAt),
    );

    expect(await scanArtifactFile(file), contains(token));
  });

  test('returns no findings for a large clean artifact', () async {
    final directory = await Directory.systemTemp.createTemp('fishergo-scan-');
    addTearDown(() => directory.delete(recursive: true));

    final file = File('${directory.path}${Platform.pathSeparator}bundle.bin');
    await file.writeAsString('x' * (artifactScanChunkSize * 2));

    expect(await scanArtifactFile(file), isEmpty);
  });
}
