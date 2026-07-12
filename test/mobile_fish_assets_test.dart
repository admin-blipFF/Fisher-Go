import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

void main() {
  test('mobile fish assets replace the oversized generated bundle', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('assets/fish/mobile/'));
    expect(pubspec, isNot(contains('- assets/fish/icons/generated/')));

    final files = Directory('assets/fish/mobile')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.png'))
        .toList(growable: false);
    expect(files.length, greaterThanOrEqualTo(300));

    for (final file in files) {
      final decoded = image.decodePng(file.readAsBytesSync());
      expect(decoded, isNotNull, reason: file.path);
      expect(decoded!.width, lessThanOrEqualTo(384), reason: file.path);
      expect(decoded.height, lessThanOrEqualTo(384), reason: file.path);
    }
  });
}
