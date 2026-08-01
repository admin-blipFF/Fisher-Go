import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final root = Directory.current.path;

  String read(String relativePath) =>
      File('$root${Platform.pathSeparator}$relativePath').readAsStringSync();

  test('Flutter does not package the local environment file', () {
    final pubspec = read('pubspec.yaml');
    final buildScript = read('scripts/vercel-build.sh');
    final main = read('lib/main.dart');

    expect(pubspec, isNot(contains('    - .env')));
    expect(buildScript, isNot(contains('cat > .env')));
    expect(main, isNot(contains('dotenv.load')));
  });

  test('client recognition uses the authenticated function boundary', () {
    final service =
        read('lib/features/catches/data/fish_recognition_service.dart');
    final publicConfig = read('lib/core/config/public_app_config.dart');
    final buildScript = read('scripts/vercel-build.sh');

    expect(service, contains('functions.invoke'));
    expect(publicConfig, contains("defaultValue: 'recognize-fish'"));
    expect(service, isNot(contains('VECTOR_ENGINE_API_KEY')));
    expect(buildScript, isNot(contains('VECTOR_ENGINE_API_KEY')));
  });

  test('release build invokes the client artifact secret scanner', () {
    final scanner = read('tool/check_client_artifacts_for_secrets.dart');
    final buildScript = read('scripts/vercel-build.sh');

    expect(scanner, contains('VECTOR_ENGINE_API_KEY'));
    expect(scanner, contains('-----BEGIN PRIVATE KEY-----'));
    expect(scanner, contains('RandomAccessFile'));
    expect(scanner, contains('artifactScanChunkSize'));
    expect(scanner, isNot(contains('readAsBytesSync')));
    expect(buildScript, contains('check_client_artifacts_for_secrets.dart'));
  });

  test('Vercel SPA fallback does not turn a forbidden env path into index.html',
      () {
    final vercel = read('vercel.json');
    final deploy = read('scripts/deploy.sh');

    expect(vercel, contains('assets/\\\\.env'));
    expect(vercel, contains('"source": "/release-manifest.json"'));
    expect(vercel, isNot(contains('"source": "/(.*)"')));
    expect(deploy, contains('npx --yes vercel deploy . --prod'));
    expect(deploy, contains(r'--project="$VERCEL_PROJECT"'));
  });

  test('Android smoke helper rejects the API 23 photo-frame target', () {
    final helper = read('tool/android_smoke_preflight.ps1');

    expect(helper, contains("KnownInvalidSerial = '0123456789ABCDEF'"));
    expect(helper, contains('MinimumApi = 35'));
    expect(helper, contains('below required API'));
  });

  test('compressed fish asset pipeline is reproducible', () {
    final pipeline = read('tool/build_mobile_fish_webp.ps1');

    expect(pipeline, contains('assets\\fish\\mobile_webp'));
    expect(pipeline, contains('libwebp'));
    expect(pipeline, contains('Quality = 82'));
  });
}
