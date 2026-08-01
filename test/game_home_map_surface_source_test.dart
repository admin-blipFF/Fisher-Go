import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('GameHome keeps the map surface independent from HUD rebuilds', () {
    final source = File(
      'lib/features/game_home/presentation/game_home_screen.dart',
    ).readAsStringSync();

    expect(
        source, contains('class _GameHomeMapSurface extends StatefulWidget'));
    expect(source, contains('late final ValueNotifier<_GameMapSurfaceData>'));
    expect(source, contains('late final Widget _mapSurfaceWidget'));
    expect(source, contains('ValueListenableBuilder<_GameMapSurfaceData>'));
    expect(source, contains('_syncMapSurfaceState();'));
  });
}
