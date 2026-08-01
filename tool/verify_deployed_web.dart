import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const _revalidatingCacheDirectives = <String>[
  'no-cache',
  'no-store',
  'must-revalidate',
];
const _immutableCacheDirectives = <String>[
  'max-age=31536000',
  'immutable',
];

class DeploymentCheckResult {
  const DeploymentCheckResult({
    required this.rootStatuses,
    required this.secretAssetStatuses,
    required this.bootstrapSignatures,
    required this.cacheControlHeaders,
    required this.releaseManifestStatuses,
    required this.releaseManifestIds,
    required this.errors,
  });

  final Map<Uri, int> rootStatuses;
  final Map<Uri, int> secretAssetStatuses;
  final Map<Uri, String> bootstrapSignatures;
  final Map<Uri, String> cacheControlHeaders;
  final Map<Uri, int> releaseManifestStatuses;
  final Map<Uri, String> releaseManifestIds;
  final List<String> errors;

  bool get passed => errors.isEmpty;
}

Future<DeploymentCheckResult> verifyDeployedWeb({
  required List<Uri> aliases,
  String? expectedReleaseId,
  http.Client? client,
}) async {
  final requestClient = client ?? http.Client();
  final rootStatuses = <Uri, int>{};
  final secretAssetStatuses = <Uri, int>{};
  final bootstrapSignatures = <Uri, String>{};
  final cacheControlHeaders = <Uri, String>{};
  final releaseManifestStatuses = <Uri, int>{};
  final releaseManifestIds = <Uri, String>{};
  final errors = <String>[];

  try {
    if (aliases.isEmpty) {
      errors.add('At least one public deployment alias is required.');
    }

    for (final alias in aliases) {
      final root = await _get(
        requestClient,
        alias,
        errors,
      );
      if (root == null) {
        continue;
      }

      rootStatuses[alias] = root.statusCode;
      if (root.statusCode != 200) {
        errors
            .add('$alias returned HTTP ${root.statusCode} for the root page.');
      }

      if (_isVercelDeploymentProtectionPage(root.body)) {
        errors.add(
          '$alias is behind Vercel Deployment Protection; use an '
          'authenticated deployment check for this preview.',
        );
        continue;
      }

      if (root.statusCode == 200) {
        _requireCacheControl(
          response: root,
          uri: alias,
          expected: _revalidatingCacheDirectives,
          cacheControlHeaders: cacheControlHeaders,
          errors: errors,
        );
      }

      final bootstrapPath = extractBootstrapScriptPath(root.body);
      if (bootstrapPath == null) {
        errors.add('$alias does not expose a Flutter bootstrap script.');
      } else {
        final bootstrap = await _get(
          requestClient,
          alias.resolve(bootstrapPath),
          errors,
        );
        if (bootstrap == null) {
          continue;
        }
        if (bootstrap.statusCode != 200) {
          errors.add(
            '$alias returned HTTP ${bootstrap.statusCode} for '
            'flutter_bootstrap.js.',
          );
        } else {
          _requireCacheControl(
            response: bootstrap,
            uri: alias.resolve(bootstrapPath),
            expected: _revalidatingCacheDirectives,
            cacheControlHeaders: cacheControlHeaders,
            errors: errors,
          );
        }
        final mainJsPath = extractMainJsSignature(bootstrap.body);
        if (mainJsPath == null) {
          errors.add('$alias does not expose a versioned main.dart.js path.');
        } else {
          bootstrapSignatures[alias] = mainJsPath;
          final mainJsUri = alias.resolve(mainJsPath);
          final mainJs = await _get(requestClient, mainJsUri, errors);
          if (mainJs == null) {
            continue;
          }
          if (mainJs.statusCode != 200) {
            errors.add(
              '$alias returned HTTP ${mainJs.statusCode} for '
              '$mainJsPath.',
            );
          } else {
            _requireCacheControl(
              response: mainJs,
              uri: mainJsUri,
              expected: _immutableCacheDirectives,
              cacheControlHeaders: cacheControlHeaders,
              errors: errors,
            );
          }
        }
      }

      final secretUri = _assetUri(alias, 'assets/.env');
      final secret = await _get(requestClient, secretUri, errors);
      if (secret == null) {
        continue;
      }

      secretAssetStatuses[alias] = secret.statusCode;
      if (secret.statusCode == 200) {
        errors.add('$secretUri is publicly accessible (HTTP 200).');
      }

      final manifestUri = _assetUri(alias, 'release-manifest.json');
      final manifest = await _get(requestClient, manifestUri, errors);
      if (manifest == null) {
        continue;
      }
      releaseManifestStatuses[alias] = manifest.statusCode;
      if (manifest.statusCode != 200) {
        errors.add(
          '$alias returned HTTP ${manifest.statusCode} for '
          'release-manifest.json.',
        );
        continue;
      }
      _requireCacheControl(
        response: manifest,
        uri: manifestUri,
        expected: _revalidatingCacheDirectives,
        cacheControlHeaders: cacheControlHeaders,
        errors: errors,
      );
      try {
        final decoded = jsonDecode(manifest.body);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('manifest is not a JSON object');
        }
        const requiredFields = <String>[
          'release_id',
          'app_version',
          'build_id',
          'build_time',
          'git_sha',
        ];
        for (final field in requiredFields) {
          final value = decoded[field];
          if (value is! String || value.trim().isEmpty) {
            throw FormatException('missing $field');
          }
        }
        final releaseId = decoded['release_id'] as String;
        releaseManifestIds[alias] = releaseId;
        if (expectedReleaseId != null &&
            releaseId != expectedReleaseId.trim()) {
          errors.add(
            '$alias serves release "$releaseId"; expected '
            '"${expectedReleaseId.trim()}".',
          );
        }
      } on Object catch (error) {
        errors.add('$manifestUri has an invalid release manifest: $error');
      }
    }

    final uniqueSignatures = bootstrapSignatures.values.toSet();
    if (bootstrapSignatures.length > 1 && uniqueSignatures.length != 1) {
      errors.add('Public aliases do not serve the same Flutter bootstrap.');
    }
    final uniqueReleaseIds = releaseManifestIds.values.toSet();
    if (releaseManifestIds.length > 1 && uniqueReleaseIds.length != 1) {
      errors.add('Public aliases do not serve the same release manifest.');
    }

    return DeploymentCheckResult(
      rootStatuses: rootStatuses,
      secretAssetStatuses: secretAssetStatuses,
      bootstrapSignatures: bootstrapSignatures,
      cacheControlHeaders: cacheControlHeaders,
      releaseManifestStatuses: releaseManifestStatuses,
      releaseManifestIds: releaseManifestIds,
      errors: List.unmodifiable(errors),
    );
  } finally {
    if (client == null) {
      requestClient.close();
    }
  }
}

void _requireCacheControl({
  required http.Response response,
  required Uri uri,
  required List<String> expected,
  required Map<Uri, String> cacheControlHeaders,
  required List<String> errors,
}) {
  final actual = _headerValue(response, 'cache-control');
  if (actual != null) {
    cacheControlHeaders[uri] = actual;
  }
  final hasAllDirectives = actual != null &&
      expected.every((directive) => _hasCacheDirective(actual, directive));
  if (!hasAllDirectives) {
    errors.add(
      '$uri has Cache-Control "${actual ?? 'missing'}"; expected '
      '${expected.join(', ')}.',
    );
  }
}

String? _headerValue(http.Response response, String name) {
  for (final entry in response.headers.entries) {
    if (entry.key.toLowerCase() == name.toLowerCase()) {
      return entry.value;
    }
  }
  return null;
}

bool _hasCacheDirective(String header, String directive) {
  return header
      .split(',')
      .map((value) => value.trim().toLowerCase())
      .any((value) => value == directive.toLowerCase());
}

String? extractBootstrapScriptPath(String html) {
  final match = RegExp(
    r'(?:src|href)="([^"]*(?:flutter_bootstrap|main\.dart)\.js[^\"]*)"',
    caseSensitive: false,
  ).firstMatch(html);
  return match?.group(1);
}

String? extractMainJsSignature(String bootstrap) {
  return RegExp(r'"mainJsPath"\s*:\s*"([^"]+)"')
      .firstMatch(bootstrap)
      ?.group(1);
}

bool _isVercelDeploymentProtectionPage(String html) {
  final normalized = html.toLowerCase();
  return normalized.contains('data-dpl-id=') &&
      (normalized.contains('/_next/') ||
          normalized.contains('vercel') ||
          normalized.contains('authentication'));
}

Uri _assetUri(Uri alias, String path) {
  return alias.replace(path: '/$path', query: null, fragment: null);
}

Future<http.Response?> _get(
  http.Client client,
  Uri uri,
  List<String> errors,
) async {
  try {
    return await client.get(
      uri,
      headers: const {'cache-control': 'no-cache'},
    );
  } on Object catch (error) {
    errors.add('$uri could not be checked: $error');
    return null;
  }
}

Future<void> main(List<String> args) async {
  final aliases = <Uri>[];
  String? expectedReleaseId;
  for (final arg in args) {
    final value = arg.startsWith('--url=')
        ? arg.substring('--url='.length)
        : arg.startsWith('--alias=')
            ? arg.substring('--alias='.length)
            : null;
    if (value != null && value.isNotEmpty) {
      aliases.add(Uri.parse(value));
    }
    if (arg.startsWith('--release-id=')) {
      expectedReleaseId = arg.substring('--release-id='.length);
    }
  }

  if (aliases.isEmpty) {
    stderr.writeln(
      'Usage: dart run tool/verify_deployed_web.dart '
      '--url=https://fisher-go.app [--alias=https://www.fisher-go.app] '
      '[--release-id=app-version-git-sha]',
    );
    exitCode = 2;
    return;
  }

  final result = await verifyDeployedWeb(
    aliases: aliases,
    expectedReleaseId: expectedReleaseId,
  );
  for (final entry in result.rootStatuses.entries) {
    stdout.writeln('${entry.key}: root HTTP ${entry.value}');
  }
  for (final entry in result.secretAssetStatuses.entries) {
    stdout.writeln('${entry.key}: /assets/.env HTTP ${entry.value}');
  }
  for (final entry in result.releaseManifestStatuses.entries) {
    stdout.writeln('${entry.key}: /release-manifest.json HTTP ${entry.value}');
  }
  for (final entry in result.releaseManifestIds.entries) {
    stdout.writeln('${entry.key}: release_id ${entry.value}');
  }
  for (final entry in result.cacheControlHeaders.entries) {
    stdout.writeln('${entry.key}: Cache-Control ${entry.value}');
  }

  if (result.passed) {
    stdout.writeln('Deployed web verification passed.');
    return;
  }

  stderr.writeln('Deployed web verification failed:');
  for (final error in result.errors) {
    stderr.writeln(' - $error');
  }
  exitCode = 1;
}
