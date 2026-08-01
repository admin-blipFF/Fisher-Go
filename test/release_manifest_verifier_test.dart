import 'package:flutter_test/flutter_test.dart';

import '../tool/verify_release_manifests.dart';

void main() {
  test('release manifests accept shared release identity', () {
    final mismatches = compareReleaseManifests(
      _manifest(buildId: 'android-7'),
      _manifest(buildId: 'web-7'),
    );

    expect(mismatches, isEmpty);
  });

  test('release manifests reject a cross-platform identity mismatch', () {
    final mismatches = compareReleaseManifests(
      _manifest(buildId: 'android-7'),
      _manifest(buildId: 'web-7', releaseId: '0.1.1-other'),
    );

    expect(mismatches, contains(contains('release_id')));
  });
}

Map<String, String> _manifest({
  required String buildId,
  String releaseId = '0.1.1-abc123456789',
}) {
  return {
    'release_id': releaseId,
    'app_version': '0.1.1+2',
    'build_id': buildId,
    'build_time': '2026-08-01T00:00:00Z',
    'git_sha': 'abc123456789',
  };
}
