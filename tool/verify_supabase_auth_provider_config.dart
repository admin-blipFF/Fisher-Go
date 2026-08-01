import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const _operationTimeout = Duration(seconds: 20);

Uri _endpoint(String baseUrl, String path) {
  final base = baseUrl.endsWith('/')
      ? baseUrl.substring(0, baseUrl.length - 1)
      : baseUrl;
  return Uri.parse('$base$path');
}

Future<void> main() async {
  final url = Platform.environment['SUPABASE_URL']?.trim() ?? '';
  final anonKey = Platform.environment['SUPABASE_ANON_KEY']?.trim() ?? '';
  final requireGoogle =
      Platform.environment['FISHERGO_REQUIRE_GOOGLE_PROVIDER']?.trim() ==
          'true';
  final missing = <String>[
    if (url.isEmpty) 'SUPABASE_URL',
    if (anonKey.isEmpty) 'SUPABASE_ANON_KEY',
  ];
  if (missing.isNotEmpty) {
    stderr.writeln(
      'SKIP: Auth provider config check needs ${missing.join(', ')}.',
    );
    exitCode = 2;
    return;
  }

  final client = http.Client();
  try {
    final response = await client.get(
      _endpoint(url, '/auth/v1/settings'),
      headers: <String, String>{
        'apikey': anonKey,
        'Authorization': 'Bearer $anonKey',
      },
    ).timeout(_operationTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'GET /auth/v1/settings returned HTTP ${response.statusCode}',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('Auth settings returned ${decoded.runtimeType}');
    }
    final external = decoded['external'];
    if (external is! Map<String, dynamic>) {
      throw StateError('Auth settings has no external provider map');
    }
    final googleEnabled = external['google'] == true;
    final anonymousEnabled = external['anonymous_users'] == true;
    stdout.writeln(
      'PASS: google_enabled=$googleEnabled '
      'anonymous_enabled=$anonymousEnabled.',
    );
    if (requireGoogle && !googleEnabled) {
      throw StateError('Google provider is disabled in Supabase Auth.');
    }
  } on TimeoutException {
    rethrow;
  } finally {
    client.close();
  }
}
