import 'dart:io';

import 'package:fishergo/core/update/update_prompt_overlay.dart';
import 'package:fishergo/core/update/update_version.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only prompts when a non-zero build is newer than the stored build', () {
    expect(shouldPromptForAppUpdate(lastBuild: 0, currentBuild: 10), isFalse);
    expect(shouldPromptForAppUpdate(lastBuild: 10, currentBuild: 0), isFalse);
    expect(shouldPromptForAppUpdate(lastBuild: 10, currentBuild: 10), isFalse);
    expect(shouldPromptForAppUpdate(lastBuild: 10, currentBuild: 9), isFalse);
    expect(shouldPromptForAppUpdate(lastBuild: 10, currentBuild: 11), isTrue);
  });

  test('accepts both Vercel and Flutter version manifest fields', () {
    expect(parseAppBuildNumber({'build_id': '202607191212'}), 202607191212);
    expect(parseAppBuildNumber({'build_number': '7'}), 7);
    expect(parseAppBuildNumber({'build_id': 'bad'}), 0);
  });

  test('AppShell schedules the web update check after the first frame', () {
    final source = File('lib/core/widgets/app_shell.dart').readAsStringSync();

    expect(source, contains('checkForAppUpdate(context)'));
    expect(source, contains('addPostFrameCallback'));
  });

  test('Vercel build emits a cache-busting version manifest', () {
    final script = File('scripts/vercel-build.sh').readAsStringSync();
    final deployScript = File('scripts/deploy.sh').readAsStringSync();

    expect(script, contains('build/web/version.json'));
    expect(script, contains('release-manifest.json'));
    expect(script, contains('BUILD_ID'));
    expect(deployScript, contains('build/web/version.json'));
    expect(deployScript, contains('release-manifest.json'));
    expect(deployScript, contains('BUILD_ID'));
  });
}
