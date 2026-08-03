import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/verify_release_readiness.dart';

void main() {
  test('reports a healthy Web package and valid public metadata', () async {
    final root = await Directory.systemTemp.createTemp('fishergo-readiness-');
    addTearDown(() => root.delete(recursive: true));
    final web = Directory('${root.path}${Platform.pathSeparator}web')
      ..createSync();
    final assets = Directory('${web.path}${Platform.pathSeparator}assets')
      ..createSync();
    File('${web.path}${Platform.pathSeparator}index.html')
        .writeAsStringSync('html');
    File('${web.path}${Platform.pathSeparator}main.dart.js')
        .writeAsStringSync('js');
    File('${assets.path}${Platform.pathSeparator}map.webp')
        .writeAsStringSync('map');
    File('${web.path}${Platform.pathSeparator}release-manifest.json')
        .writeAsStringSync(jsonEncode(_manifest('release-1')));

    final report = await inspectReleaseReadiness(
      webRoot: web,
      androidOutputRoot:
          Directory('${root.path}${Platform.pathSeparator}missing-android'),
      releaseRoot:
          Directory('${root.path}${Platform.pathSeparator}missing-release'),
      environment: const {
        'FISHERGO_PRIVACY_URL': 'https://fisher-go.app/privacy',
        'FISHERGO_SUPPORT_EMAIL': 'support@fisher-go.app',
      },
      verifyAndroidSigning: false,
    );

    expect(
      report.checks.firstWhere((check) => check.name == 'Web package').status,
      ReadinessStatus.pass,
    );
    expect(
      report.checks
          .firstWhere((check) => check.name == 'Public release metadata')
          .status,
      ReadinessStatus.pass,
    );
    expect(report.hasFailures, isFalse);
  });

  test('fails closed when cross-platform release identities differ', () async {
    final root = await Directory.systemTemp.createTemp('fishergo-readiness-');
    addTearDown(() => root.delete(recursive: true));
    final web = Directory('${root.path}${Platform.pathSeparator}web')
      ..createSync();
    final release = Directory('${root.path}${Platform.pathSeparator}release')
      ..createSync();
    for (final file in <String>['index.html', 'main.dart.js']) {
      File('${web.path}${Platform.pathSeparator}$file').writeAsStringSync(file);
    }
    File('${web.path}${Platform.pathSeparator}release-manifest.json')
        .writeAsStringSync(jsonEncode(_manifest('web-release')));
    File('${release.path}${Platform.pathSeparator}release-manifest.json')
        .writeAsStringSync(jsonEncode(_manifest('android-release')));

    final report = await inspectReleaseReadiness(
      webRoot: web,
      androidOutputRoot:
          Directory('${root.path}${Platform.pathSeparator}missing-android'),
      releaseRoot: release,
      environment: const <String, String>{},
      verifyAndroidSigning: false,
    );

    final identity = report.checks
        .firstWhere((check) => check.name == 'Cross-platform release identity');
    expect(identity.status, ReadinessStatus.fail);
    expect(identity.detail, contains('release_id'));
  });

  test('detects a forbidden client token in an artifact', () async {
    final root = await Directory.systemTemp.createTemp('fishergo-readiness-');
    addTearDown(() => root.delete(recursive: true));
    final web = Directory('${root.path}${Platform.pathSeparator}web')
      ..createSync();
    File('${web.path}${Platform.pathSeparator}index.html')
        .writeAsStringSync('html');
    File('${web.path}${Platform.pathSeparator}main.dart.js')
        .writeAsStringSync('SUPABASE_SERVICE_ROLE_KEY');

    final report = await inspectReleaseReadiness(
      webRoot: web,
      androidOutputRoot:
          Directory('${root.path}${Platform.pathSeparator}missing-android'),
      releaseRoot:
          Directory('${root.path}${Platform.pathSeparator}missing-release'),
      environment: const <String, String>{},
      verifyAndroidSigning: false,
    );

    final scan = report.checks
        .firstWhere((check) => check.name == 'Client artifact secret scan');
    expect(scan.status, ReadinessStatus.fail);
    expect(scan.detail, contains('SUPABASE_SERVICE_ROLE_KEY'));
  });

  test('does not require owner-only Android signing in a source audit',
      () async {
    final report = await inspectReleaseReadiness(
      webRoot: Directory('missing-web'),
      androidOutputRoot: Directory('missing-android'),
      releaseRoot: Directory('missing-release'),
      environment: const <String, String>{},
      verifyAndroidSigning: false,
    );

    final signing = report.checks
        .firstWhere((check) => check.name == 'Android release signing');
    expect(signing.status, ReadinessStatus.skip);
  });

  test('recognizes jarsigner unsigned output even when the process exits zero',
      () {
    expect(jarsignerOutputIsUnsigned('no manifest.\njar is unsigned.'), isTrue);
    expect(jarsignerOutputIsUnsigned('jar verified.'), isFalse);
  });
}

Map<String, String> _manifest(String releaseId) => {
      'release_id': releaseId,
      'app_version': '0.1.1+2',
      'build_id': 'web-1',
      'build_time': '2026-08-03 00:00 HKT',
      'git_sha': 'abc123456789',
    };
