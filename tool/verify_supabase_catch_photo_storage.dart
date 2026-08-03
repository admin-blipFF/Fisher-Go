import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';

import 'package:http/http.dart' as http;

const _bucket = 'catch-photos';
const _operationTimeout = Duration(seconds: 20);
const _cleanupTimeout = Duration(seconds: 10);

Uri _endpoint(String baseUrl, String path) {
  final base = baseUrl.endsWith('/')
      ? baseUrl.substring(0, baseUrl.length - 1)
      : baseUrl;
  return Uri.parse('$base$path');
}

Map<String, String> _headers(String anonKey, [String? accessToken]) {
  return <String, String>{
    'apikey': anonKey,
    if (accessToken != null) 'Authorization': 'Bearer $accessToken',
  };
}

Future<Object?> _jsonRequest(
  http.Client client,
  Uri uri, {
  required String method,
  required Map<String, String> headers,
  required Object body,
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
        '${method.toUpperCase()} $uri returned HTTP ${response.statusCode}');
  }
  final decoded = jsonDecode(response.body);
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
  final anonymousSmoke =
      Platform.environment['FISHERGO_SMOKE_ANONYMOUS']?.trim().toLowerCase() ==
          'true';
  final email = Platform.environment['FISHERGO_SMOKE_EMAIL']?.trim() ?? '';
  final password = Platform.environment['FISHERGO_SMOKE_PASSWORD'] ?? '';

  final missing = <String>[
    if (url.isEmpty) 'SUPABASE_URL',
    if (anonKey.isEmpty) 'SUPABASE_ANON_KEY',
    if (!anonymousSmoke && email.isEmpty) 'FISHERGO_SMOKE_EMAIL',
    if (!anonymousSmoke && password.isEmpty) 'FISHERGO_SMOKE_PASSWORD',
  ];
  if (missing.isNotEmpty) {
    stderr.writeln(
      'SKIP: configured Supabase catch-photo smoke needs '
      '${missing.join(', ')}.',
    );
    exitCode = 2;
    return;
  }

  stderr.writeln('SMOKE: creating bounded HTTP client.');
  final client = http.Client();
  stderr.writeln('SMOKE: bounded HTTP client ready.');
  final smokePath =
      'smoke-${DateTime.now().toUtc().millisecondsSinceEpoch}.png';
  String? uploadedPath;
  String? accessToken;
  try {
    stderr.writeln(
      'SMOKE: signing in (${anonymousSmoke ? 'anonymous' : 'password'}).',
    );
    final authResponse = await _jsonRequest(
      client,
      _endpoint(
          url,
          anonymousSmoke
              ? '/auth/v1/signup'
              : '/auth/v1/token?grant_type=password'),
      method: 'POST',
      headers: _headers(anonKey),
      body: anonymousSmoke
          ? <String, Object>{'data': <String, Object>{}}
          : <String, String>{'email': email, 'password': password},
    ).timeout(_operationTimeout);
    if (authResponse is! Map<String, dynamic>) {
      throw StateError(
        'Supabase sign-in returned JSON type ${authResponse.runtimeType}',
      );
    }
    final auth = authResponse;
    accessToken = auth['access_token'] as String?;
    final user = auth['user'];
    final userId = user is Map<String, dynamic> ? user['id'] as String? : null;
    if (accessToken == null || userId == null) {
      throw StateError('Supabase sign-in returned no session');
    }

    uploadedPath = '$userId/$smokePath';
    final bytes = Uint8List.fromList(
      <int>[137, 80, 78, 71, 13, 10, 26, 10],
    );
    stderr.writeln('SMOKE: uploading private PNG.');
    final upload = http.Request(
      'POST',
      _endpoint(url, '/storage/v1/object/$_bucket/$uploadedPath'),
    )
      ..headers.addAll(<String, String>{
        ..._headers(anonKey, accessToken),
        'Content-Type': 'image/png',
        'x-upsert': 'true',
      })
      ..bodyBytes = bytes;
    await client
        .send(upload)
        .then(http.Response.fromStream)
        .then(
          (response) => _expectSuccess(response, 'Private PNG upload'),
        )
        .timeout(_operationTimeout);
    stderr.writeln('SMOKE: creating signed URL.');
    final signedResponse = await _jsonRequest(
      client,
      _endpoint(url, '/storage/v1/object/sign/$_bucket'),
      method: 'POST',
      headers: _headers(anonKey, accessToken),
      body: <String, Object>{
        'expiresIn': 300,
        'paths': <String>[uploadedPath]
      },
    ).timeout(_operationTimeout);
    final signedPath = switch (signedResponse) {
      Map<String, dynamic>() => signedResponse['signedURL'] as String?,
      List<Object?>() when signedResponse.isNotEmpty =>
        (signedResponse.first is Map<String, dynamic>)
            ? (signedResponse.first as Map<String, dynamic>)['signedURL']
                as String?
            : null,
      _ => null,
    };
    if (signedPath == null || signedPath.isEmpty) {
      throw StateError('Signed URL response did not include signedURL');
    }
    final signedUrl = signedPath.startsWith('http')
        ? Uri.parse(signedPath)
        : _endpoint(url, '/storage/v1$signedPath');
    stderr.writeln('SMOKE: reading signed URL.');
    final response = await client.get(signedUrl).timeout(_operationTimeout);
    if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
      throw StateError(
        'Signed URL read-back failed: HTTP ${response.statusCode}',
      );
    }
    stdout.writeln(
      'PASS: private catch photo uploaded and read back for '
      '${anonymousSmoke ? 'anonymous authenticated' : 'password'} user.',
    );
  } finally {
    if (uploadedPath != null) {
      stderr.writeln('SMOKE: deleting smoke object.');
      try {
        final response = await client
            .delete(
              _endpoint(url, '/storage/v1/object/$_bucket/$uploadedPath'),
              headers: _headers(anonKey, accessToken),
            )
            .timeout(_cleanupTimeout);
        await _expectSuccess(response, 'Smoke object cleanup');
      } catch (error) {
        stderr.writeln('WARN: catch-photo cleanup failed: $error');
      }
    }
    if (accessToken != null) {
      var deletionSucceeded = false;
      try {
        stderr.writeln('SMOKE: deleting disposable account.');
        final response = await client
            .delete(
              _endpoint(url, '/auth/v1/user'),
              headers: _headers(anonKey, accessToken),
            )
            .timeout(_cleanupTimeout);
        await _expectSuccess(
          response,
          'Supabase disposable account cleanup',
        );
        deletionSucceeded = true;
      } catch (error) {
        stderr.writeln(
          'WARN: Supabase disposable account cleanup failed: $error',
        );
      }
      if (!deletionSucceeded) {
        try {
          stderr.writeln('SMOKE: signing out after cleanup failure.');
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
    }
    client.close();
  }
}
