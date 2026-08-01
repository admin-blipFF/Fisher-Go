import 'dart:convert';
import 'dart:io';

const forbiddenTokens = <String>[
  'VECTOR_ENGINE_API_KEY',
  'SUPABASE_SERVICE_ROLE_KEY',
  'VERCEL_TOKEN',
  'api.vectorengine',
  '/assets/.env',
  '\\assets\\.env',
  '-----BEGIN PRIVATE KEY-----',
];

const artifactScanChunkSize = 64 * 1024;

Future<Set<String>> scanArtifactFile(File file) async {
  final matches = <String>{};
  final overlap = forbiddenTokens.fold<int>(
        0,
        (longest, token) => token.length > longest ? token.length : longest,
      ) -
      1;
  var carry = '';
  final RandomAccessFile handle = await file.open();

  try {
    while (true) {
      final bytes = await handle.read(artifactScanChunkSize);
      if (bytes.isEmpty) break;

      final content = carry + latin1.decode(bytes, allowInvalid: true);
      for (final token in forbiddenTokens) {
        if (content.contains(token)) matches.add(token);
      }
      if (matches.length == forbiddenTokens.length) break;

      carry = content.length <= overlap
          ? content
          : content.substring(content.length - overlap);
    }
  } finally {
    await handle.close();
  }

  return matches;
}

Future<void> main(List<String> arguments) async {
  final roots = arguments.isEmpty
      ? <Directory>[
          Directory('build/web'),
          Directory('build/app/outputs'),
        ]
      : arguments.map(Directory.new).toList();

  final findings = <String>[];
  for (final root in roots) {
    if (!root.existsSync()) continue;
    for (final file in root.listSync(recursive: true).whereType<File>()) {
      final matches = await scanArtifactFile(file);
      for (final token in matches) {
        findings.add('${file.path}: $token');
      }
    }
  }

  if (findings.isNotEmpty) {
    stderr.writeln('Client artifact secret scan failed:');
    for (final finding in findings) {
      stderr.writeln(' - $finding');
    }
    exitCode = 1;
    return;
  }

  stdout.writeln('Client artifact secret scan passed.');
}
