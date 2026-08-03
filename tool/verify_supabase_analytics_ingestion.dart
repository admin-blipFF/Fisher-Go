import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const _timeout = Duration(seconds: 20);
const _cleanupTimeout = Duration(seconds: 10);

Uri _endpoint(String baseUrl, String path) {
  final base = baseUrl.endsWith('/')
      ? baseUrl.substring(0, baseUrl.length - 1)
      : baseUrl;
  return Uri.parse('$base$path');
}

Map<String, String> _headers(String anonKey, [String? accessToken]) => {
      'apikey': anonKey,
      if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    };

Future<http.Response> _post(
  http.Client client,
  Uri uri,
  Map<String, String> headers,
  Object body,
) async {
  return client
      .post(uri, headers: headers, body: jsonEncode(body))
      .timeout(_timeout);
}

Future<http.Response> _postAnalyticsEvent(
  http.Client client,
  Uri endpoint,
  String anonKey,
  String accessToken, {
  required String eventName,
  required Map<String, Object?> fields,
}) {
  return _post(
    client,
    endpoint,
    _headers(anonKey, accessToken),
    <String, Object?>{
      'p_event_name': eventName,
      'p_occurred_at': DateTime.now().toUtc().toIso8601String(),
      'p_build_time': 'hosted-smoke',
      'p_release_id': 'hosted-smoke',
      'p_environment': 'smoke',
      'p_fields': fields,
    },
  );
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
        'SKIP: analytics ingestion smoke needs Supabase URL and anon key.');
    exitCode = 2;
    return;
  }

  final hostProjectRef = Uri.parse(url).host.split('.').first;
  if (projectRef.isNotEmpty && hostProjectRef != projectRef) {
    stderr.writeln(
        'FAIL: Supabase URL project ref does not match configured ref.');
    exitCode = 1;
    return;
  }
  if (expectedProjectRef.isNotEmpty && projectRef != expectedProjectRef) {
    stderr.writeln(
        'FAIL: configured project ref does not match migration target.');
    exitCode = 1;
    return;
  }
  if ((smokeEmail.isEmpty) != (smokePassword.isEmpty)) {
    stderr.writeln(
      'FAIL: local analytics smoke email and password must be supplied together.',
    );
    exitCode = 1;
    return;
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
      throw StateError('anonymous signup returned HTTP ${signup.statusCode}');
    }
    final auth = jsonDecode(signup.body) as Map<String, dynamic>;
    accessToken = auth['access_token']?.toString().trim();
    if (accessToken == null || accessToken.isEmpty) {
      throw StateError('anonymous signup returned no access token');
    }

    final analyticsEndpoint =
        _endpoint(url, '/rest/v1/rpc/record_analytics_event');
    final response = await _postAnalyticsEvent(
      client,
      analyticsEndpoint,
      anonKey,
      accessToken,
      eventName: 'app_bootstrap',
      fields: const {
        'outcome': 'success',
        'email': 'server-filter-test',
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'analytics ingestion returned HTTP ${response.statusCode}',
      );
    }
    final mapIdleResponse = await _postAnalyticsEvent(
      client,
      analyticsEndpoint,
      anonKey,
      accessToken,
      eventName: 'map_idle',
      fields: const {'durationMs': 1320},
    );
    if (mapIdleResponse.statusCode < 200 || mapIdleResponse.statusCode >= 300) {
      throw StateError(
        'map idle analytics ingestion returned HTTP '
        '${mapIdleResponse.statusCode}',
      );
    }
    stdout.writeln(
      'PASS: authenticated analytics ingestion accepted allowlisted events '
      'without exposing a table read path.',
    );
  } catch (error) {
    stderr.writeln('FAIL: Supabase analytics ingestion smoke failed: $error');
    exitCode = 1;
  } finally {
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
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw StateError(
            'Supabase disposable account cleanup returned HTTP '
            '${response.statusCode}',
          );
        }
        deletionSucceeded = true;
      } catch (error) {
        stderr.writeln(
          'WARN: Supabase disposable account cleanup failed: $error',
        );
      }
      if (!deletionSucceeded) {
        try {
          await client
              .post(
                _endpoint(url, '/auth/v1/logout'),
                headers: _headers(anonKey, accessToken),
              )
              .timeout(_cleanupTimeout);
        } catch (error) {
          stderr.writeln('WARN: analytics smoke sign-out failed: $error');
        }
      }
    }
    client.close();
  }
}
