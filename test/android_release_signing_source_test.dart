import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android release signing is environment-driven, never debug-keyed', () {
    final gradle = File('android/app/build.gradle.kts');
    final contents = gradle.readAsStringSync();

    expect(contents, contains('FISHERGO_ANDROID_KEYSTORE_PATH'));
    expect(contents, contains('FISHERGO_ANDROID_KEYSTORE_PASSWORD'));
    expect(contents, contains('FISHERGO_ANDROID_KEY_ALIAS'));
    expect(contents, contains('FISHERGO_ANDROID_KEY_PASSWORD'));
    expect(contents, contains('FISHERGO_REQUIRE_RELEASE_SIGNING'));
    expect(contents, contains('fisherGoRelease'));
    expect(contents, isNot(contains('signingConfigs.getByName("debug")')));
  });
}
