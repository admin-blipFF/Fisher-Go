import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppShell lazily mounts secondary screens', () {
    final source = File('lib/core/widgets/app_shell.dart').readAsStringSync();

    expect(source, contains('GameScreen.values.length'));
    expect(source, contains('_builtScreens'));
    expect(source, contains('_screenWidgets'));
    expect(source, contains('Offstage('));
    expect(source, contains('if (!_builtScreens.contains(screen.index))'));
    expect(
      source,
      contains('_screenWidgets[GameScreen.map.index] = GameHomeScreen('),
    );
  });
}
