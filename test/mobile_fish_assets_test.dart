import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('mobile fish assets replace the oversized generated bundle', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('assets/fish/mobile_webp/'));
    expect(pubspec, contains('assets/fish/icons/locked_silhouette.png'));
    expect(pubspec, contains('assets/fish/icons/silhouettes/'));
    expect(pubspec, isNot(contains('    - assets/fish/icons/\n')));
    expect(pubspec, isNot(contains('- assets/fish/icons/generated/')));

    final files = Directory('assets/fish/mobile_webp')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.webp'))
        .toList(growable: false);
    expect(files.length, greaterThanOrEqualTo(300));

    expect(files, hasLength(340));
  });

  test('Vercel input excludes fish rollback and generated source assets', () {
    final vercelIgnore = File('.vercelignore').readAsStringSync();
    expect(vercelIgnore, contains('assets/fish/icons/generated/'));
    expect(vercelIgnore, contains('assets/fish/icons/backup_*/'));
  });

  test('avatar asset manifest excludes backup layers and legacy SVGs', () {
    final pubspec = File('pubspec.yaml')
        .readAsStringSync()
        .replaceAll('\r\n', '\n');
    expect(pubspec, isNot(contains('    - assets/avatar/layers/\n')));
    expect(pubspec, isNot(contains('assets/avatar/layers/_opaque_backup')));

    final pngs = Directory('assets/avatar/layers')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.toLowerCase().endsWith('.png'))
        .map((file) => file.path.replaceAll('\\', '/'))
        .toList(growable: false);
    expect(pngs, isNotEmpty);
    for (final path in pngs) {
      expect(pubspec, contains('    - $path'));
    }
    final avatarEntries = pubspec
        .split('\n')
        .where((line) => line.startsWith('    - assets/avatar/layers/'))
        .toList(growable: false);
    expect(avatarEntries, everyElement(endsWith('.png')),
        reason: 'Every avatar asset must be an explicit runtime PNG entry.');
  });

  test('Flutter engine decodes the compressed fish assets', () async {
    final files = Directory('assets/fish/mobile_webp')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.webp'))
        .toList(growable: false);

    for (final file in files) {
      final codec = await ui.instantiateImageCodec(file.readAsBytesSync());
      final frame = await codec.getNextFrame();
      expect(frame.image.width, lessThanOrEqualTo(384), reason: file.path);
      expect(frame.image.height, lessThanOrEqualTo(384), reason: file.path);
      frame.image.dispose();
      codec.dispose();
    }
  });
}
