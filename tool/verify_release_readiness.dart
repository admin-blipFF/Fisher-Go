import 'dart:convert';
import 'dart:io';

import 'check_asset_budget.dart';
import 'check_client_artifacts_for_secrets.dart';
import 'verify_public_release_config.dart';
import 'verify_release_manifests.dart';

enum ReadinessStatus { pass, fail, ownerGate, skip }

class ReadinessCheck {
  const ReadinessCheck({
    required this.name,
    required this.status,
    required this.detail,
  });

  final String name;
  final ReadinessStatus status;
  final String detail;
}

class ReleaseReadinessReport {
  const ReleaseReadinessReport(this.checks);

  final List<ReadinessCheck> checks;

  bool get isReady => checks.every(
        (check) => check.status == ReadinessStatus.pass,
      );

  bool get hasFailures => checks.any(
        (check) => check.status == ReadinessStatus.fail,
      );
}

bool jarsignerOutputIsUnsigned(String output) {
  return output.toLowerCase().contains('jar is unsigned');
}

Future<ReleaseReadinessReport> inspectReleaseReadiness({
  Directory? webRoot,
  Directory? androidOutputRoot,
  Directory? releaseRoot,
  Map<String, String>? environment,
  bool verifyAndroidSigning = true,
}) async {
  final resolvedWebRoot = webRoot ?? Directory('build/web');
  final resolvedAndroidRoot =
      androidOutputRoot ?? Directory('build/app/outputs');
  final resolvedReleaseRoot = releaseRoot ?? Directory('build/release');
  final checks = <ReadinessCheck>[];

  checks.add(_inspectWebPackage(resolvedWebRoot));
  checks.add(_inspectAndroidArtifact(resolvedAndroidRoot));
  checks.add(_inspectManifestIdentity(resolvedWebRoot, resolvedReleaseRoot));
  checks.add(await _inspectSecretScan(
    <Directory>[resolvedWebRoot, resolvedAndroidRoot, resolvedReleaseRoot],
  ));
  checks.add(_inspectAssetBudget(
    webRoot: resolvedWebRoot,
    androidOutputRoot: resolvedAndroidRoot,
  ));
  checks.add(_inspectPublicConfiguration(environment ?? Platform.environment));
  checks.add(await _inspectAndroidSigning(
    androidOutputRoot: resolvedAndroidRoot,
    releaseRoot: resolvedReleaseRoot,
    enabled: verifyAndroidSigning,
  ));

  return ReleaseReadinessReport(List.unmodifiable(checks));
}

ReadinessCheck _inspectWebPackage(Directory root) {
  if (!root.existsSync()) {
    return ReadinessCheck(
      name: 'Web package',
      status: ReadinessStatus.skip,
      detail: 'package root is not present: ${root.path}',
    );
  }

  final required = <String>[
    'index.html',
    'main.dart.js',
    'release-manifest.json'
  ];
  final missing = required
      .where((name) =>
          !File('${root.path}${Platform.pathSeparator}$name').existsSync())
      .toList(growable: false);
  if (missing.isNotEmpty) {
    return ReadinessCheck(
      name: 'Web package',
      status: ReadinessStatus.fail,
      detail: 'missing required files: ${missing.join(', ')}',
    );
  }
  return ReadinessCheck(
    name: 'Web package',
    status: ReadinessStatus.pass,
    detail: 'index, bootstrap, and release manifest are present',
  );
}

ReadinessCheck _inspectAndroidArtifact(Directory root) {
  if (!root.existsSync()) {
    return ReadinessCheck(
      name: 'Android artifact',
      status: ReadinessStatus.skip,
      detail: 'output root is not present: ${root.path}',
    );
  }
  final bundles = root
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.toLowerCase().endsWith('.aab'))
      .toList(growable: false);
  if (bundles.isEmpty) {
    return ReadinessCheck(
      name: 'Android artifact',
      status: ReadinessStatus.skip,
      detail: 'no Android AAB is present under ${root.path}',
    );
  }
  final names = bundles.map((file) => file.path).join(', ');
  return ReadinessCheck(
    name: 'Android artifact',
    status: ReadinessStatus.pass,
    detail: 'AAB present: $names',
  );
}

ReadinessCheck _inspectManifestIdentity(
  Directory webRoot,
  Directory releaseRoot,
) {
  final webManifest = File(
    '${webRoot.path}${Platform.pathSeparator}release-manifest.json',
  );
  final androidManifest = File(
    '${releaseRoot.path}${Platform.pathSeparator}release-manifest.json',
  );
  if (!webManifest.existsSync() || !androidManifest.existsSync()) {
    return ReadinessCheck(
      name: 'Cross-platform release identity',
      status: ReadinessStatus.skip,
      detail: 'both Web and Android manifests are required for comparison',
    );
  }

  try {
    final web = _readManifest(webManifest);
    final android = _readManifest(androidManifest);
    final mismatches = compareReleaseManifests(android, web);
    if (mismatches.isNotEmpty) {
      return ReadinessCheck(
        name: 'Cross-platform release identity',
        status: ReadinessStatus.fail,
        detail: mismatches.join('; '),
      );
    }
    return const ReadinessCheck(
      name: 'Cross-platform release identity',
      status: ReadinessStatus.pass,
      detail: 'release_id, app_version, and git_sha match',
    );
  } on Object catch (error) {
    return ReadinessCheck(
      name: 'Cross-platform release identity',
      status: ReadinessStatus.fail,
      detail: 'manifest parsing failed: $error',
    );
  }
}

Future<ReadinessCheck> _inspectSecretScan(List<Directory> roots) async {
  final existingRoots = roots.where((root) => root.existsSync()).toList();
  if (existingRoots.isEmpty) {
    return const ReadinessCheck(
      name: 'Client artifact secret scan',
      status: ReadinessStatus.skip,
      detail: 'no built artifact directory is present',
    );
  }

  final findings = <String>[];
  for (final root in existingRoots) {
    for (final file in root.listSync(recursive: true).whereType<File>()) {
      final matches = await scanArtifactFile(file);
      for (final token in matches) {
        findings.add('${file.path}: $token');
      }
    }
  }
  if (findings.isNotEmpty) {
    return ReadinessCheck(
      name: 'Client artifact secret scan',
      status: ReadinessStatus.fail,
      detail: 'forbidden tokens found: ${findings.join('; ')}',
    );
  }
  return ReadinessCheck(
    name: 'Client artifact secret scan',
    status: ReadinessStatus.pass,
    detail: 'scanned ${existingRoots.length} artifact roots',
  );
}

ReadinessCheck _inspectAssetBudget({
  required Directory webRoot,
  required Directory androidOutputRoot,
}) {
  final hasWeb = webRoot.existsSync();
  final hasAndroid = androidOutputRoot.existsSync();
  if (!hasWeb && !hasAndroid) {
    return const ReadinessCheck(
      name: 'Asset and bundle budgets',
      status: ReadinessStatus.skip,
      detail: 'no built package is present',
    );
  }

  final assetRoot = Directory(
    '${webRoot.path}${Platform.pathSeparator}assets',
  );
  final report = inspectAssetBudget(
    webRoot: hasWeb ? webRoot : null,
    androidOutputRoot: hasAndroid ? androidOutputRoot : null,
    packagedAssetRoot: assetRoot.existsSync() ? assetRoot : null,
  );
  if (report.violations.isNotEmpty) {
    return ReadinessCheck(
      name: 'Asset and bundle budgets',
      status: ReadinessStatus.fail,
      detail: report.violations.join('; '),
    );
  }
  final webSize = report.webPackageBytes == null
      ? 'Web n/a'
      : 'Web ${_formatMiB(report.webPackageBytes!)} MiB';
  final androidCount = report.androidArtifactBytes.length;
  return ReadinessCheck(
    name: 'Asset and bundle budgets',
    status: ReadinessStatus.pass,
    detail: '$webSize; Android AABs $androidCount; no forbidden assets',
  );
}

ReadinessCheck _inspectPublicConfiguration(Map<String, String> environment) {
  final privacyUrl = environment['FISHERGO_PRIVACY_URL'] ?? '';
  final supportEmail = environment['FISHERGO_SUPPORT_EMAIL'] ?? '';
  if (privacyUrl.trim().isEmpty && supportEmail.trim().isEmpty) {
    return const ReadinessCheck(
      name: 'Public release metadata',
      status: ReadinessStatus.ownerGate,
      detail: 'production privacy URL and support email were not supplied',
    );
  }

  final issues = validatePublicReleaseConfig(
    privacyPolicyUrl: privacyUrl,
    supportEmail: supportEmail,
  );
  if (issues.isNotEmpty) {
    return ReadinessCheck(
      name: 'Public release metadata',
      status: ReadinessStatus.fail,
      detail: issues.join('; '),
    );
  }
  return const ReadinessCheck(
    name: 'Public release metadata',
    status: ReadinessStatus.pass,
    detail: 'HTTPS privacy URL and support email are valid',
  );
}

Future<ReadinessCheck> _inspectAndroidSigning({
  required Directory androidOutputRoot,
  required Directory releaseRoot,
  required bool enabled,
}) async {
  if (!enabled) {
    return const ReadinessCheck(
      name: 'Android release signing',
      status: ReadinessStatus.skip,
      detail: 'signature verification disabled by caller',
    );
  }

  final artifacts = <File>[];
  if (androidOutputRoot.existsSync()) {
    artifacts.addAll(
      androidOutputRoot
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.toLowerCase().endsWith('.aab')),
    );
  }
  if (releaseRoot.existsSync()) {
    artifacts.addAll(
      releaseRoot
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.toLowerCase().endsWith('.apk')),
    );
  }
  if (artifacts.isEmpty) {
    return const ReadinessCheck(
      name: 'Android release signing',
      status: ReadinessStatus.skip,
      detail: 'no Android release artifacts are present',
    );
  }

  var unsigned = false;
  final failures = <String>[];
  for (final artifact in artifacts) {
    ProcessResult result;
    try {
      result = await Process.run(
        'jarsigner',
        <String>['-verify', '-verbose:summary', artifact.path],
        runInShell: true,
      );
    } on ProcessException {
      failures.add(artifact.path);
      continue;
    }
    final output = '${result.stdout}\n${result.stderr}'.toLowerCase();
    if (jarsignerOutputIsUnsigned(output)) {
      unsigned = true;
    } else if (result.exitCode != 0) {
      failures.add(artifact.path);
    }
  }
  if (failures.isNotEmpty) {
    return ReadinessCheck(
      name: 'Android release signing',
      status: ReadinessStatus.fail,
      detail: 'jarsigner failed for ${failures.join(', ')}',
    );
  }
  if (unsigned) {
    return const ReadinessCheck(
      name: 'Android release signing',
      status: ReadinessStatus.ownerGate,
      detail:
          'one or more local artifacts are unsigned; protected keystore is required',
    );
  }
  return ReadinessCheck(
    name: 'Android release signing',
    status: ReadinessStatus.pass,
    detail: 'verified ${artifacts.length} Android artifacts',
  );
}

Map<String, dynamic> _readManifest(File file) {
  final decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('release manifest must be a JSON object');
  }
  return decoded;
}

String _formatMiB(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);

String _statusLabel(ReadinessStatus status) {
  switch (status) {
    case ReadinessStatus.pass:
      return 'PASS';
    case ReadinessStatus.fail:
      return 'FAIL';
    case ReadinessStatus.ownerGate:
      return 'OWNER_GATE';
    case ReadinessStatus.skip:
      return 'SKIP';
  }
}

void main(List<String> arguments) async {
  final report = await inspectReleaseReadiness(
    webRoot: _directoryArgument(arguments, '--web-root'),
    androidOutputRoot: _directoryArgument(arguments, '--android-output-root'),
    releaseRoot: _directoryArgument(arguments, '--release-root'),
    verifyAndroidSigning: !arguments.contains('--skip-signing'),
  );

  stdout.writeln('FisherGO release readiness (read-only)');
  for (final check in report.checks) {
    stdout.writeln(
        '${_statusLabel(check.status).padRight(10)} ${check.name}: ${check.detail}');
  }
  final counts = <ReadinessStatus, int>{};
  for (final check in report.checks) {
    counts[check.status] = (counts[check.status] ?? 0) + 1;
  }
  stdout.writeln(
    'Summary: ${counts[ReadinessStatus.pass] ?? 0} pass, '
    '${counts[ReadinessStatus.fail] ?? 0} fail, '
    '${counts[ReadinessStatus.ownerGate] ?? 0} owner gate, '
    '${counts[ReadinessStatus.skip] ?? 0} skipped',
  );

  if (report.hasFailures || arguments.contains('--strict') && !report.isReady) {
    exitCode = 1;
  }
}

Directory? _directoryArgument(List<String> arguments, String name) {
  final prefix = '$name=';
  for (final argument in arguments) {
    if (argument.startsWith(prefix)) {
      return Directory(argument.substring(prefix.length));
    }
  }
  return null;
}
