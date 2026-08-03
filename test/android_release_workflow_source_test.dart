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
        r"FISHERGO_ACCOUNT_DELETION_ENABLED: ${{ vars.FISHERGO_ACCOUNT_DELETION_ENABLED || 'false' }}",
      ),
    );
    expect(source, contains('name: Verify production build configuration'));
    expect(source, contains(r'test -n "$SUPABASE_URL"'));
    expect(source, contains(r'test -n "$SUPABASE_ANON_KEY"'));
    expect(source, contains(r'test -n "$SUPABASE_PROJECT_REF"'));
    expect(source, contains(r'test -n "$FISHERGO_PRIVACY_URL"'));
    expect(source, contains(r'test -n "$FISHERGO_SUPPORT_EMAIL"'));
    expect(source, contains('tool/verify_public_release_config.dart'));
    expect(source, contains('name: Verify Supabase project identity'));
    expect(source, contains('tool/verify_supabase_project_identity.dart'));
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
    expect(
      source,
      contains('--dart-define=FISHERGO_ACCOUNT_DELETION_ENABLED='),
    );
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
    expect(source, contains('build/release/app-release-arm64.apk'));
    expect(source, contains('build/app/symbols/'));
    expect(source, contains('build/web/release-manifest.json'));
    expect(source, contains('if-no-files-found: error'));
    expect(source, contains('retention-days: 14'));
    expect(source, isNot(contains('continue-on-error: true')));
  });

  test('Android release smoke exercises the signed configuration on API 35',
      () {
    final source = File(
      '.github/workflows/android-release.yml',
    ).readAsStringSync();

    expect(source, contains('Build signed Android x64 smoke APK'));
    expect(source, contains('--target-platform android-x64'));
    expect(source, contains('--dart-define=FISHERGO_MAP_PERF=true'));
    expect(source, contains('build/release/app-release-arm64.apk'));
    expect(source, contains('build/release/app-release-x64-smoke.apk'));
    expect(source, contains('reactivecircus/android-emulator-runner@v2'));
    expect(source, contains('api-level: 35'));
    expect(source, contains('tool/android_map_benchmark.ps1'));
    expect(
      source,
      contains('-ApkPath build/release/app-release-x64-smoke.apk'),
    );
    expect(source, contains('-Variant signed-release-api35'));
    expect(source, contains('-WarmupRounds 1'));
    expect(source, contains('-RequireHostGpu'));
    expect(source, contains('-RequireMapReadiness'));
    expect(source, contains('tmp/android-release-smoke-api35.json'));
    expect(source, contains('android-release-smoke-api35'));
    expect(source, contains('name: API 35 signed release APK smoke'));
    expect(source, contains('build/web build/app/outputs build/release'));
  });
}
