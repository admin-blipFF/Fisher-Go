import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const _timeout = Duration(seconds: 20);

Uri _endpoint(String baseUrl, String path) {
  final base = baseUrl.endsWith('/')
      ? baseUrl.substring(0, baseUrl.length - 1)
      : baseUrl;
  return Uri.parse('$base$path');
}

Map<String, String> _headers(String anonKey, [String? accessToken]) => {
      'apikey': anonKey,
      if (accessToken != null) 'Authorization': 'Bearer $accessToken',
    };

Future<http.Response> _post(
  http.Client client,
  Uri uri,
  Map<String, String> headers,
  Object body,
) async {
  return client
      .post(
        uri,
        headers: {...headers, 'Content-Type': 'application/json'},
        body: jsonEncode(body),
      )
      .timeout(_timeout);
}

Future<void> main() async {
  final url = Platform.environment['SUPABASE_URL']?.trim() ?? '';
  final anonKey = Platform.environment['SUPABASE_ANON_KEY']?.trim() ?? '';
  final projectRef = Platform.environment['SUPABASE_PROJECT_REF']?.trim() ?? '';
  final expectedProjectRef =
      Platform.environment['SUPABASE_EXPECTED_PROJECT_REF']?.trim() ?? '';
  final smokeEmail = Platform.environment['FISHERGO_SMOKE_EMAIL']?.trim() ?? '';
  final smokePassword =
      Platform.environment['FISHERGO_SMOKE_PASSWORD']?.trim() ?? '';

  if (url.isEmpty || anonKey.isEmpty) {
    stderr.writeln(
      'SKIP: event configuration smoke needs Supabase URL and anon key.',
    );
    exitCode = 2;
    return;
  }
  if ((smokeEmail.isEmpty) != (smokePassword.isEmpty)) {
    stderr.writeln(
      'FAIL: event configuration smoke email/password must be supplied together.',
    );
    exitCode = 1;
    return;
  }
  if (projectRef.isNotEmpty) {
    final urlProjectRef = Uri.parse(url).host.split('.').first;
    if (urlProjectRef != projectRef ||
        (expectedProjectRef.isNotEmpty && projectRef != expectedProjectRef)) {
      stderr.writeln('FAIL: event configuration smoke project ref mismatch.');
      exitCode = 1;
      return;
    }
  }

  final client = http.Client();
  String? accessToken;
  try {
    final signup = await _post(
      client,
      _endpoint(url, '/auth/v1/signup'),
      _headers(anonKey),
      smokeEmail.isEmpty
          ? const <String, Object?>{'data': <String, Object?>{}}
          : <String, Object?>{
              'email': smokeEmail,
              'password': smokePassword,
            },
    );
    if (signup.statusCode < 200 || signup.statusCode >= 300) {
      throw StateError('signup returned HTTP ${signup.statusCode}');
    }
    final auth = jsonDecode(signup.body) as Map<String, dynamic>;
    accessToken = auth['access_token']?.toString().trim();
    if (accessToken == null || accessToken.isEmpty) {
      throw StateError('signup returned no access token');
    }

    final response = await _post(
      client,
      _endpoint(url, '/rest/v1/rpc/get_active_fishing_event_config'),
      _headers(anonKey, accessToken),
      const <String, Object?>{},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'event configuration RPC returned HTTP ${response.statusCode}',
      );
    }
    final raw = jsonDecode(response.body);
    if (raw is! List) {
      throw StateError('event configuration RPC returned non-list JSON');
    }
    for (final item in raw) {
      if (item is! Map) {
        throw StateError('event configuration row is not an object');
      }
      final multiplier = (item['multiplier'] as num?)?.toDouble();
      if (multiplier == null || !multiplier.isFinite || multiplier <= 0) {
        throw StateError('event configuration returned an invalid multiplier');
      }
    }
    stdout.writeln(
      'PASS: server event configuration projection responded with '
      '${raw.length} valid active rows.',
    );
  } catch (error) {
    stderr.writeln('FAIL: Supabase event configuration smoke failed: $error');
    exitCode = 1;
  } finally {
    if (accessToken != null) {
      try {
        await client
            .post(
              _endpoint(url, '/auth/v1/logout'),
              headers: _headers(anonKey, accessToken),
            )
            .timeout(const Duration(seconds: 10));
      } catch (_) {
        stderr.writeln('WARN: event configuration smoke sign-out failed.');
      }
    }
    client.close();
  }
}
