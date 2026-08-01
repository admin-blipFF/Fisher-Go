import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const _operationTimeout = Duration(seconds: 20);
const _cleanupTimeout = Duration(seconds: 10);
const _emailRedirectTo = 'https://fisher-go.app';

Uri _endpoint(
  String baseUrl,
  String path, [
  Map<String, String>? queryParameters,
]) {
  final base = baseUrl.endsWith('/')
      ? baseUrl.substring(0, baseUrl.length - 1)
      : baseUrl;
  final uri = Uri.parse('$base$path');
  if (queryParameters == null) {
    return uri;
  }
  return uri.replace(
    queryParameters: <String, String>{
      ...uri.queryParameters,
      ...queryParameters,
    },
  );
}

Map<String, String> _headers(String anonKey, [String? accessToken]) {
  return <String, String>{
    'apikey': anonKey,
    if (accessToken != null) 'Authorization': 'Bearer $accessToken',
  };
}

Future<Map<String, dynamic>> _jsonRequest(
  http.Client client,
  Uri uri, {
  required String method,
  required Map<String, String> headers,
  required Map<String, Object?> body,
}) async {
  final request = http.Request(method, uri)
    ..headers.addAll(<String, String>{
      ...headers,
      'Content-Type': 'application/json',
    })
    ..body = jsonEncode(body);
  final response = await client.send(request).then(http.Response.fromStream);
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw StateError(
      '${method.toUpperCase()} $uri returned HTTP ${response.statusCode}',
    );
  }
  final decoded = jsonDecode(response.body);
  if (decoded is! Map<String, dynamic>) {
    throw StateError(
      '${method.toUpperCase()} $uri returned JSON type '
      '${decoded.runtimeType}',
    );
  }
  return decoded;
}

Future<void> _expectSuccess(http.Response response, String operation) async {
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw StateError('$operation failed: HTTP ${response.statusCode}');
  }
}

Future<void> main() async {
  final url = Platform.environment['SUPABASE_URL']?.trim() ?? '';
  final anonKey = Platform.environment['SUPABASE_ANON_KEY']?.trim() ?? '';
  final email =
      Platform.environment['FISHERGO_SMOKE_UPGRADE_EMAIL']?.trim() ?? '';
  final password =
      Platform.environment['FISHERGO_SMOKE_UPGRADE_PASSWORD'] ?? '';

  final missing = <String>[
    if (url.isEmpty) 'SUPABASE_URL',
    if (anonKey.isEmpty) 'SUPABASE_ANON_KEY',
    if (email.isEmpty) 'FISHERGO_SMOKE_UPGRADE_EMAIL',
    if (password.isEmpty) 'FISHERGO_SMOKE_UPGRADE_PASSWORD',
  ];
  if (missing.isNotEmpty) {
    stderr.writeln(
      'SKIP: auth upgrade smoke needs ${missing.join(', ')}.',
    );
    exitCode = 2;
    return;
  }

  final client = http.Client();
  String? accessToken;
  String? anonymousUserId;
  try {
    stderr.writeln('SMOKE: creating bounded HTTP client.');
    final anonymousResponse = await _jsonRequest(
      client,
      _endpoint(url, '/auth/v1/signup'),
      method: 'POST',
      headers: _headers(anonKey),
      body: <String, Object?>{'data': <String, Object?>{}},
    ).timeout(_operationTimeout);
    accessToken = anonymousResponse['access_token'] as String?;
    final anonymousUser = anonymousResponse['user'];
    anonymousUserId = anonymousUser is Map<String, dynamic>
        ? anonymousUser['id'] as String?
        : null;
    if (accessToken == null || anonymousUserId == null) {
      throw StateError('Anonymous sign-in returned no session');
    }
    final anonymousIsAnonymous = anonymousUser is Map<String, dynamic>
        ? anonymousUser['is_anonymous'] == true
        : false;
    if (!anonymousIsAnonymous) {
      throw StateError(
        'Supabase signup did not return an anonymous user identity',
      );
    }

    stderr.writeln('SMOKE: upgrading anonymous identity to email/password.');
    final upgradeResponse = await _jsonRequest(
      client,
      _endpoint(
        url,
        '/auth/v1/user',
        <String, String>{'redirect_to': _emailRedirectTo},
      ),
      method: 'PUT',
      headers: _headers(anonKey, accessToken),
      body: <String, Object?>{'email': email, 'password': password},
    ).timeout(_operationTimeout);
    final upgradedUser = upgradeResponse['user'];
    final upgradedUserId = upgradedUser is Map<String, dynamic>
        ? upgradedUser['id'] as String?
        : null;
    final upgradedIsAnonymous = upgradedUser is Map<String, dynamic>
        ? upgradedUser['is_anonymous'] == true
        : false;
    if (upgradedUserId == null || upgradedUserId != anonymousUserId) {
      throw StateError(
        'Email upgrade changed or lost the anonymous user identity',
      );
    }
    if (upgradedIsAnonymous) {
      throw StateError('Email upgrade left the user marked as anonymous');
    }

    stdout.writeln(
      'PASS: anonymous Email upgrade preserved the Supabase user identity.',
    );
  } catch (error) {
    stderr.writeln('FAIL: Supabase auth upgrade smoke failed: $error');
    exitCode = 1;
  } finally {
    if (accessToken != null) {
      try {
        stderr.writeln('SMOKE: signing out.');
        final response = await client
            .post(
              _endpoint(url, '/auth/v1/logout'),
              headers: _headers(anonKey, accessToken),
            )
            .timeout(_cleanupTimeout);
        await _expectSuccess(response, 'Supabase smoke sign-out');
      } catch (error) {
        stderr.writeln('WARN: Supabase smoke sign-out failed: $error');
      }
    }
    client.close();
  }
}
