import 'dart:async';
import 'dart:io';

import 'package:fishergo/core/config/supabase_project_identity.dart';
import 'package:http/http.dart' as http;

const _operationTimeout = Duration(seconds: 20);

Uri _endpoint(String baseUrl, String path) {
  final base = baseUrl.endsWith('/')
      ? baseUrl.substring(0, baseUrl.length - 1)
      : baseUrl;
  return Uri.parse('$base$path');
}

Map<String, String> _headers(String anonKey) => <String, String>{
      'apikey': anonKey,
      'Authorization': 'Bearer $anonKey',
      'Accept': 'application/json',
    };

Future<void> main() async {
  final url = Platform.environment['SUPABASE_URL']?.trim() ?? '';
  final anonKey = Platform.environment['SUPABASE_ANON_KEY']?.trim() ?? '';
  final projectRef = Platform.environment['SUPABASE_PROJECT_REF']?.trim() ?? '';
  final missing = <String>[
    if (url.isEmpty) 'SUPABASE_URL',
    if (anonKey.isEmpty) 'SUPABASE_ANON_KEY',
    if (projectRef.isEmpty) 'SUPABASE_PROJECT_REF',
  ];
  if (missing.isNotEmpty) {
    stderr.writeln(
      'SKIP: Supabase project identity check needs ${missing.join(', ')}.',
    );
    exitCode = 2;
    return;
  }

  final client = http.Client();
  try {
    final parsedUrl = Uri.parse(url);
    if (!isTrustedSupabaseUrl(parsedUrl, projectRef)) {
      throw StateError(
        'Supabase URL must be the canonical HTTPS host for project ref',
      );
    }

    final response = await client
        .get(
          _endpoint(url, '/auth/v1/settings'),
          headers: _headers(anonKey),
        )
        .timeout(_operationTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Supabase project identity endpoint returned HTTP '
        '${response.statusCode}',
      );
    }
    stdout.writeln(
        'PASS: Supabase URL and project ref identify one reachable project.');
  } on TimeoutException {
    stderr.writeln('FAIL: Supabase project identity check timed out.');
    exitCode = 1;
  } catch (error) {
    stderr.writeln('FAIL: Supabase project identity check failed: $error');
    exitCode = 1;
  } finally {
    client.close();
  }
}
