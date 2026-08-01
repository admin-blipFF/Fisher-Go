import 'dart:io';

const defaultWebPackageBudgetBytes = 100 * 1024 * 1024;
const defaultAndroidArtifactBudgetBytes = 100 * 1024 * 1024;

class AssetBudgetReport {
  const AssetBudgetReport({
    required this.webPackageBytes,
    required this.androidArtifactBytes,
    required this.violations,
  });

  final int? webPackageBytes;
  final Map<String, int> androidArtifactBytes;
  final List<String> violations;

  bool get passed => violations.isEmpty;
}

AssetBudgetReport inspectAssetBudget({
  Directory? webRoot,
  Directory? androidOutputRoot,
  Directory? packagedAssetRoot,
  int maxWebPackageBytes = defaultWebPackageBudgetBytes,
  int maxAndroidArtifactBytes = defaultAndroidArtifactBudgetBytes,
}) {
  final violations = <String>[];
  int? webPackageBytes;
  final androidArtifactBytes = <String, int>{};

  if (webRoot != null) {
    if (!webRoot.existsSync()) {
      violations.add('Web package root not found: ${webRoot.path}');
    } else {
      webPackageBytes = _directorySize(webRoot);
      if (webPackageBytes > maxWebPackageBytes) {
        violations.add(
          'Web package is ${_formatMiB(webPackageBytes)} MiB; '
          'budget is ${_formatMiB(maxWebPackageBytes)} MiB',
        );
      }
    }
  }

  if (androidOutputRoot != null) {
    if (!androidOutputRoot.existsSync()) {
      violations.add(
        'Android bundle output root not found: ${androidOutputRoot.path}',
      );
    } else {
      final bundles = androidOutputRoot
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.toLowerCase().endsWith('.aab'));
      for (final bundle in bundles) {
        final size = bundle.lengthSync();
        androidArtifactBytes[bundle.path] = size;
        if (size > maxAndroidArtifactBytes) {
          violations.add(
            'Android artifact ${bundle.path} is ${_formatMiB(size)} MiB; '
            'budget is ${_formatMiB(maxAndroidArtifactBytes)} MiB',
          );
        }
      }
      if (androidArtifactBytes.isEmpty) {
        violations.add(
          'No Android AAB found under ${androidOutputRoot.path}',
        );
      }
    }
  }

  if (packagedAssetRoot != null) {
    if (!packagedAssetRoot.existsSync()) {
      violations.add(
        'Packaged asset root not found: ${packagedAssetRoot.path}',
      );
    } else {
      for (final file
          in packagedAssetRoot.listSync(recursive: true).whereType<File>()) {
        if (_isForbiddenPackagedAsset(file, packagedAssetRoot)) {
          violations.add(
            'forbidden packaged asset: ${_relativePath(file, packagedAssetRoot)}',
          );
        }
      }
    }
  }

  return AssetBudgetReport(
    webPackageBytes: webPackageBytes,
    androidArtifactBytes: Map.unmodifiable(androidArtifactBytes),
    violations: List.unmodifiable(violations),
  );
}

int _directorySize(Directory directory) {
  return directory
      .listSync(recursive: true)
      .whereType<File>()
      .fold<int>(0, (total, file) => total + file.lengthSync());
}

bool _isForbiddenPackagedAsset(File file, Directory root) {
  final relative = _relativePath(file, root).toLowerCase();
  final fileName = relative.split('/').last;
  final pathSegments = relative.split('/');

  if (fileName == '.env' || fileName.startsWith('.env.')) return true;
  if (fileName.contains('backup') || fileName.contains('audit')) return true;
  if (fileName.endsWith('.bak') || fileName.endsWith('.tmp')) return true;
  if (pathSegments.any((segment) =>
      segment == 'backup' ||
      segment == 'backups' ||
      segment == 'tmp' ||
      segment == 'temp' ||
      segment == 'audit')) {
    return true;
  }
  return fileName.endsWith('.zip') ||
      fileName.endsWith('.tar') ||
      fileName.endsWith('.tar.gz');
}

String _relativePath(File file, Directory root) {
  final rootPath = root.absolute.path.endsWith(Platform.pathSeparator)
      ? root.absolute.path
      : '${root.absolute.path}${Platform.pathSeparator}';
  return file.absolute.path
      .replaceFirst(rootPath, '')
      .replaceAll(Platform.pathSeparator, '/');
}

String _formatMiB(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);

void main(List<String> arguments) {
  final webRoot = _directoryArgument(
    arguments,
    '--web-root',
    fallback: Directory('build/web'),
  );
  final androidOutputRoot = _directoryArgument(
    arguments,
    '--android-output-root',
    fallback: Directory('build/app/outputs'),
  );
  final packagedAssetRoot = _directoryArgument(
    arguments,
    '--packaged-asset-root',
    fallback: Directory('build/web/assets'),
  );

  final report = inspectAssetBudget(
    webRoot: webRoot,
    androidOutputRoot: androidOutputRoot,
    packagedAssetRoot: packagedAssetRoot,
  );
  if (report.webPackageBytes case final bytes?) {
    stdout.writeln('Web package: ${_formatMiB(bytes)} MiB');
  }
  for (final entry in report.androidArtifactBytes.entries) {
    stdout.writeln('${entry.key}: ${_formatMiB(entry.value)} MiB');
  }
  if (report.passed) {
    stdout.writeln('Asset budget check passed.');
    return;
  }

  stderr.writeln('Asset budget check failed:');
  for (final violation in report.violations) {
    stderr.writeln(' - $violation');
  }
  exitCode = 1;
}

Directory _directoryArgument(
  List<String> arguments,
  String name, {
  required Directory fallback,
}) {
  final prefix = '$name=';
  for (final argument in arguments) {
    if (argument.startsWith(prefix)) {
      return Directory(argument.substring(prefix.length));
    }
  }
  return fallback;
}
