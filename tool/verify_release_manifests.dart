import 'dart:convert';
import 'dart:io';

const _identityFields = <String>['release_id', 'app_version', 'git_sha'];

List<String> compareReleaseManifests(
  Map<String, dynamic> first,
  Map<String, dynamic> second,
) {
  final mismatches = <String>[];
  for (final field in _identityFields) {
    final firstValue = first[field];
    final secondValue = second[field];
    if (firstValue is! String || firstValue.trim().isEmpty) {
      mismatches.add('first manifest has no valid $field');
      continue;
    }
    if (secondValue is! String || secondValue.trim().isEmpty) {
      mismatches.add('second manifest has no valid $field');
      continue;
    }
    if (firstValue != secondValue) {
      mismatches.add('$field differs: "$firstValue" != "$secondValue"');
    }
  }
  return mismatches;
}

Map<String, dynamic> _readManifest(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    throw ArgumentError('Release manifest does not exist: $path');
  }
  final decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Release manifest must be a JSON object.');
  }
  return decoded;
}

Future<void> main(List<String> args) async {
  if (args.length != 2) {
    stderr.writeln(
      'Usage: dart run tool/verify_release_manifests.dart '
      '<first-manifest> <second-manifest>',
    );
    exitCode = 2;
    return;
  }

  try {
    final mismatches = compareReleaseManifests(
      _readManifest(args[0]),
      _readManifest(args[1]),
    );
    if (mismatches.isNotEmpty) {
      stderr.writeln('Release identity mismatch:');
      for (final mismatch in mismatches) {
        stderr.writeln('- $mismatch');
      }
      exitCode = 1;
      return;
    }
    stdout.writeln('Release identity verified across both manifests.');
  } on Object catch (error) {
    stderr.writeln('Unable to verify release manifests: $error');
    exitCode = 1;
  }
}
