import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const _operationTimeout = Duration(seconds: 20);
const _cleanupTimeout = Duration(seconds: 10);

Uri _endpoint(String baseUrl, String path) {
  final base = baseUrl.endsWith('/')
      ? baseUrl.substring(0, baseUrl.length - 1)
      : baseUrl;
  return Uri.parse('$base$path');
}

Map<String, String> _headers(String key, [String? accessToken]) {
  return <String, String>{
    'apikey': key,
    if (accessToken != null) 'Authorization': 'Bearer $accessToken',
  };
}

Object? _decode(http.Response response) {
  if (response.body.trim().isEmpty) return null;
  return jsonDecode(response.body);
}

void _expectSuccess(http.Response response, String operation) {
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw StateError('$operation failed: HTTP ${response.statusCode}');
  }
}

Future<void> main() async {
  final url = Platform.environment['SUPABASE_URL']?.trim() ?? '';
  final anonKey = Platform.environment['SUPABASE_ANON_KEY']?.trim() ?? '';
  final serviceRoleKey =
      Platform.environment['SUPABASE_SERVICE_ROLE_KEY']?.trim() ?? '';
  final email =
      Platform.environment['FISHERGO_SMOKE_DELETION_EMAIL']?.trim() ?? '';
  final password =
      Platform.environment['FISHERGO_SMOKE_DELETION_PASSWORD'] ?? '';

  final missing = <String>[
    if (url.isEmpty) 'SUPABASE_URL',
    if (anonKey.isEmpty) 'SUPABASE_ANON_KEY',
    if (serviceRoleKey.isEmpty) 'SUPABASE_SERVICE_ROLE_KEY',
    if (email.isEmpty) 'FISHERGO_SMOKE_DELETION_EMAIL',
    if (password.isEmpty) 'FISHERGO_SMOKE_DELETION_PASSWORD',
  ];
  if (missing.isNotEmpty) {
    stderr.writeln(
      'SKIP: account deletion smoke needs ${missing.join(', ')}.',
    );
    exitCode = 2;
    return;
  }

  final client = http.Client();
  String? accessToken;
  String? userId;
  var deletionSucceeded = false;
  try {
    stderr.writeln('SMOKE: creating disposable password account.');
    final signup = await client
        .post(
          _endpoint(url, '/auth/v1/signup'),
          headers: <String, String>{
            ..._headers(anonKey),
            'Content-Type': 'application/json',
          },
          body: jsonEncode(<String, Object>{
            'email': email,
            'password': password,
            'data': <String, Object>{},
          }),
        )
        .timeout(_operationTimeout);
    _expectSuccess(signup, 'Disposable account signup');
    final signupBody = _decode(signup);
    if (signupBody is! Map<String, dynamic>) {
      throw StateError('Signup returned an unexpected JSON body');
    }
    accessToken = signupBody['access_token'] as String?;
    final user = signupBody['user'];
    userId = user is Map<String, dynamic> ? user['id'] as String? : null;
    if (accessToken == null || userId == null) {
      throw StateError(
        'Signup returned no session; disable email confirmation for the smoke user',
      );
    }

    stderr.writeln('SMOKE: invoking protected delete-account function.');
    final deletion = await client
        .post(
          _endpoint(url, '/functions/v1/delete-account'),
          headers: <String, String>{
            ..._headers(anonKey, accessToken),
            'Content-Type': 'application/json',
          },
          body: '{}',
        )
        .timeout(_operationTimeout);
    _expectSuccess(deletion, 'Account deletion function');
    final payload = _decode(deletion);
    if (payload is! Map<String, dynamic> || payload['deleted'] != true) {
      throw StateError('Account deletion did not return deleted=true');
    }
    deletionSucceeded = true;

    final sessionCheck = await client
        .get(
          _endpoint(url, '/auth/v1/user'),
          headers: _headers(anonKey, accessToken),
        )
        .timeout(_operationTimeout);
    if (sessionCheck.statusCode != 401 && sessionCheck.statusCode != 404) {
      throw StateError(
        'Deleted account session remained usable: HTTP ${sessionCheck.statusCode}',
      );
    }
    stdout.writeln(
      'PASS: protected account deletion removed the disposable Auth user.',
    );
  } catch (error) {
    stderr.writeln('FAIL: account deletion smoke failed: $error');
    exitCode = 1;
  } finally {
    if (!deletionSucceeded && userId != null) {
      stderr.writeln('SMOKE: cleaning up disposable account after failure.');
      try {
        final cleanup = await client
            .delete(
              _endpoint(url, '/auth/v1/admin/users/$userId'),
              headers: _headers(serviceRoleKey, serviceRoleKey),
            )
            .timeout(_cleanupTimeout);
        if (cleanup.statusCode < 200 || cleanup.statusCode >= 300) {
          stderr.writeln(
            'WARN: disposable account cleanup returned HTTP ${cleanup.statusCode}.',
          );
        }
      } catch (error) {
        stderr.writeln('WARN: disposable account cleanup failed: $error');
      }
    }
    client.close();
  }
}
