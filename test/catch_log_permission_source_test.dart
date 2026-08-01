import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CatchLog defers location access until the explicit locate action', () {
    final source = File(
      'lib/features/catches/presentation/catch_log_screen.dart',
    ).readAsStringSync();
    final initStart = source.indexOf('void initState()');
    final disposeStart =
        source.indexOf('@override\n  void dispose()', initStart);
    final initBody = source.substring(initStart, disposeStart);

    expect(initBody, isNot(contains('_startLocationTracking();')));
    expect(source, contains('onPressed: _pickLocation'));
    expect(source, contains('LocationAccessService'));
  });

  test('Android declares the Android 14 selected-photo permission', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(
      manifest,
      contains('android.permission.READ_MEDIA_VISUAL_USER_SELECTED'),
    );
    expect(manifest, isNot(contains('android.permission.CAMERA')));
  });
}
