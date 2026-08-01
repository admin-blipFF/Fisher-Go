import 'dart:convert';
import 'dart:io';

String _env(String name) => Platform.environment[name]?.trim() ?? '';

String _appVersion() {
  final pubspec = File('pubspec.yaml').readAsStringSync();
  final match = RegExp(r'^version:\s*([^\s#]+)', multiLine: true).firstMatch(
    pubspec,
  );
  return match?.group(1) ?? 'unknown';
}

String _shortSha(String sha) {
  if (sha.isEmpty || sha == 'unknown') return 'unknown';
  return sha.length > 12 ? sha.substring(0, 12) : sha;
}

Future<void> main(List<String> args) async {
  if (args.length != 1 || args.single.trim().isEmpty) {
    stderr.writeln(
      'Usage: dart run tool/write_release_manifest.dart <output-path>',
    );
    exitCode = 2;
    return;
  }

  final buildId = _env('FISHERGO_BUILD_ID').isNotEmpty
      ? _env('FISHERGO_BUILD_ID')
      : DateTime.now().toUtc().millisecondsSinceEpoch.toString();
  final buildTime = _env('FISHERGO_BUILD_TIME').isNotEmpty
      ? _env('FISHERGO_BUILD_TIME')
      : DateTime.now().toUtc().toIso8601String();
  final gitSha = [
    _env('FISHERGO_GIT_SHA'),
    _env('VERCEL_GIT_COMMIT_SHA'),
    _env('GITHUB_SHA'),
  ].firstWhere((value) => value.isNotEmpty, orElse: () => 'unknown');
  final appVersion = _appVersion();
  final releaseId = _env('FISHERGO_RELEASE_ID').isNotEmpty
      ? _env('FISHERGO_RELEASE_ID')
      : gitSha == 'unknown'
          ? '$appVersion-$buildId'
          : '$appVersion-${_shortSha(gitSha)}';

  final output = File(args.single);
  output.parent.createSync(recursive: true);
  output.writeAsStringSync(
    '${jsonEncode(<String, String>{
          'release_id': releaseId,
          'app_version': appVersion,
          'build_id': buildId,
          'build_time': buildTime,
          'git_sha': gitSha,
        })}\n',
  );
  stdout.writeln('Release manifest written: ${output.path}');
}
