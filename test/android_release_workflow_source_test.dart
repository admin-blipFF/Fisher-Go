import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android release workflow requires protected signing evidence', () {
    final source = File(
      '.github/workflows/android-release.yml',
    ).readAsStringSync();

    expect(source, contains('workflow_dispatch:'));
    expect(source, contains('permissions:'));
    expect(source, contains('contents: read'));
    expect(source, contains('environment: fishergo-android-release'));
    expect(source, contains('tool/write_release_manifest.dart'));
    expect(source, contains('build/release/release-manifest.json'));
    expect(source, contains('build/web/release-manifest.json'));
    expect(source, contains('tool/verify_release_manifests.dart'));
    expect(source, contains('Verify cross-platform release identity'));
    expect(source, contains('Resolve release id'));
    expect(source, contains('FISHERGO_RELEASE_ID'));
    expect(
      source,
      contains(
        r'FISHERGO_ANDROID_KEYSTORE_BASE64: ${{ secrets.FISHERGO_ANDROID_KEYSTORE_BASE64 }}',
      ),
    );
    expect(
      source,
      contains(r'base64 --decode > "$RUNNER_TEMP/fishergo-upload.jks"'),
    );
    expect(source, contains(r'test -s "$RUNNER_TEMP/fishergo-upload.jks"'));
    expect(source, contains('name: Validate protected upload keystore'));
    expect(
      source,
      contains(r'test -n "$FISHERGO_ANDROID_KEYSTORE_PASSWORD"'),
    );
    expect(
      source,
      contains(r'test -n "$FISHERGO_ANDROID_KEY_PASSWORD"'),
    );
    expect(source, contains(r'test -n "$FISHERGO_ANDROID_KEY_ALIAS"'));
    expect(source, contains('keytool -list'));
    expect(source, contains(r'-alias "$FISHERGO_ANDROID_KEY_ALIAS"'));
    expect(source, contains("FISHERGO_REQUIRE_RELEASE_SIGNING: 'true'"));
    expect(
      source,
      contains(
        r'FISHERGO_ANDROID_KEYSTORE_PATH: ${{ runner.temp }}/fishergo-upload.jks',
      ),
    );
    expect(source, contains('flutter build appbundle --release'));
    expect(source, contains('flutter build apk --release'));
    expect(source, contains('--dart-define=FISHERGO_PRIVACY_URL='));
    expect(source, contains('--dart-define=FISHERGO_SUPPORT_EMAIL='));
    expect(source, contains('--split-debug-info=build/app/symbols/aab'));
    expect(source, contains('--split-debug-info=build/app/symbols/apk'));
    expect(source, contains('--target-platform android-arm64'));
    expect(source, contains('name: Verify Dart symbol files'));
    expect(
        source, contains('find build/app/symbols -type f -name \'*.symbols\''));
    expect(source, contains('build/app/symbols'));
    expect(source, contains('jarsigner -verify'));
    expect(source, contains('app-release.apk'));
    expect(source, contains('tool/check_client_artifacts_for_secrets.dart'));
    expect(source, contains('tool/check_asset_budget.dart'));
    expect(source, contains('actions/upload-artifact@v4'));
    expect(source, contains('name: fishergo-android-release'));
    expect(
        source, contains('build/app/outputs/bundle/release/app-release.aab'));
    expect(
      source,
      contains('build/app/outputs/flutter-apk/app-release.apk'),
    );
    expect(source, contains('build/app/symbols/'));
    expect(source, contains('build/web/release-manifest.json'));
    expect(source, contains('if-no-files-found: error'));
    expect(source, contains('retention-days: 14'));
    expect(source, isNot(contains('continue-on-error: true')));
  });
}
