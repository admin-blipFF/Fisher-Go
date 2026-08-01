import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/check_asset_budget.dart';

void main() {
  test(
      'passes a small web package and Android artifact without forbidden assets',
      () async {
    final root = await Directory.systemTemp.createTemp('fishergo-budget-');
    addTearDown(() => root.delete(recursive: true));
    final webRoot = Directory('${root.path}${Platform.pathSeparator}web')
      ..createSync();
    final androidRoot = Directory(
      '${root.path}${Platform.pathSeparator}android',
    )..createSync();
    final assetRoot = Directory(
      '${webRoot.path}${Platform.pathSeparator}assets',
    )..createSync();
    File('${webRoot.path}${Platform.pathSeparator}main.dart.js')
        .writeAsStringSync('web');
    File('${assetRoot.path}${Platform.pathSeparator}map.webp')
        .writeAsStringSync('asset');
    File('${androidRoot.path}${Platform.pathSeparator}app-release.aab')
        .writeAsStringSync('bundle');

    final report = inspectAssetBudget(
      webRoot: webRoot,
      androidOutputRoot: androidRoot,
      packagedAssetRoot: assetRoot,
      maxWebPackageBytes: 1024,
      maxAndroidArtifactBytes: 1024,
    );

    expect(report.violations, isEmpty);
  });

  test('reports a web package over its budget', () async {
    final root = await Directory.systemTemp.createTemp('fishergo-budget-');
    addTearDown(() => root.delete(recursive: true));
    final file = File('${root.path}${Platform.pathSeparator}main.dart.js');
    file.writeAsStringSync('0123456789');

    final report = inspectAssetBudget(
      webRoot: root,
      maxWebPackageBytes: 5,
    );

    expect(report.violations, contains(contains('Web package')));
  });

  test('reports an oversized Android artifact and forbidden packaged asset',
      () async {
    final root = await Directory.systemTemp.createTemp('fishergo-budget-');
    addTearDown(() => root.delete(recursive: true));
    final androidRoot = Directory(
      '${root.path}${Platform.pathSeparator}android',
    )..createSync();
    final assetRoot = Directory(
      '${root.path}${Platform.pathSeparator}assets',
    )..createSync();
    File('${androidRoot.path}${Platform.pathSeparator}app-release.aab')
        .writeAsStringSync('0123456789');
    File('${assetRoot.path}${Platform.pathSeparator}backup.env')
        .writeAsStringSync('secret');

    final report = inspectAssetBudget(
      androidOutputRoot: androidRoot,
      packagedAssetRoot: assetRoot,
      maxAndroidArtifactBytes: 5,
    );

    expect(report.violations, contains(contains('Android artifact')));
    expect(report.violations, contains(contains('forbidden packaged asset')));
  });
}
