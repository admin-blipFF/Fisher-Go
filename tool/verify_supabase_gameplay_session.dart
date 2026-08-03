import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const _operationTimeout = Duration(seconds: 20);
const _cleanupTimeout = Duration(seconds: 10);

Uri _endpoint(
  String baseUrl,
  String path, [
  Map<String, String>? queryParameters,
]) {
  final base = baseUrl.endsWith('/')
      ? baseUrl.substring(0, baseUrl.length - 1)
      : baseUrl;
  final uri = Uri.parse('$base$path');
  if (queryParameters == null) return uri;
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

class _HttpFailure implements Exception {
  const _HttpFailure(this.method, this.statusCode, this.path);

  final String method;
  final int statusCode;
  final String path;

  @override
  String toString() => '$method $path returned HTTP $statusCode';
}

Future<Object?> _jsonRequest(
  http.Client client,
  Uri uri, {
  required String method,
  required Map<String, String> headers,
  Object? body,
}) async {
  final request = http.Request(method, uri)
    ..headers.addAll(<String, String>{
      ...headers,
      if (body != null) 'Content-Type': 'application/json',
    });
  if (body != null) request.body = jsonEncode(body);

  final response = await client
      .send(request)
      .then(http.Response.fromStream)
      .timeout(_operationTimeout);
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw _HttpFailure(method, response.statusCode, uri.path);
  }
  if (response.body.trim().isEmpty) return null;
  return jsonDecode(response.body);
}

Map<String, dynamic> _mapResponse(Object? value, String operation) {
  if (value is Map<String, dynamic>) return value;
  throw StateError('$operation returned ${value.runtimeType}, expected JSON');
}

String _requiredString(Map<String, dynamic> value, String key) {
  final result = value[key]?.toString().trim() ?? '';
  if (result.isEmpty) throw StateError('Response did not include $key');
  return result;
}

Future<void> _expectEarlyPullMiss(
  http.Client client,
  Uri uri,
  Map<String, String> headers,
  String sessionId,
) async {
  final result = _mapResponse(
    await _jsonRequest(
      client,
      uri,
      method: 'POST',
      headers: headers,
      body: <String, Object?>{
        'p_session_id': sessionId,
        'p_pull_elapsed_ms': 0,
      },
    ),
    'Early fishing pull',
  );
  if (result['success'] == true || result['status'] != 'resolved_miss') {
    throw StateError('Early fishing pull was not recorded as a miss');
  }
}

Future<void> main() async {
  final url = Platform.environment['SUPABASE_URL']?.trim() ?? '';
  final anonKey = Platform.environment['SUPABASE_ANON_KEY']?.trim() ?? '';
  final projectRef = Platform.environment['SUPABASE_PROJECT_REF']?.trim() ?? '';
  final expectedProjectRef =
      Platform.environment['SUPABASE_EXPECTED_PROJECT_REF']?.trim() ?? '';
  final requestedSpotId =
      Platform.environment['FISHERGO_SMOKE_GAMEPLAY_SPOT_ID']?.trim() ?? '';
  final smokeEmail = Platform.environment['FISHERGO_SMOKE_EMAIL']?.trim() ?? '';
  final smokePassword =
      Platform.environment['FISHERGO_SMOKE_PASSWORD']?.trim() ?? '';
  final missing = <String>[
    if (url.isEmpty) 'SUPABASE_URL',
    if (anonKey.isEmpty) 'SUPABASE_ANON_KEY',
    if (expectedProjectRef.isNotEmpty && projectRef.isEmpty)
      'SUPABASE_PROJECT_REF',
  ];
  if (missing.isNotEmpty) {
    stderr.writeln(
      'SKIP: gameplay session smoke needs ${missing.join(', ')}.',
    );
    exitCode = 2;
    return;
  }
  if ((smokeEmail.isEmpty) != (smokePassword.isEmpty)) {
    stderr.writeln(
      'FAIL: local gameplay smoke email and password must be supplied together.',
    );
    exitCode = 1;
    return;
  }
  if (projectRef.isNotEmpty) {
    final urlProjectRef = Uri.parse(url).host.split('.').first;
    if (urlProjectRef != projectRef) {
      stderr.writeln(
        'FAIL: Supabase URL project ref does not match configured project ref.',
      );
      exitCode = 1;
      return;
    }
    if (expectedProjectRef.isNotEmpty && projectRef != expectedProjectRef) {
      stderr.writeln(
        'FAIL: configured live project ref does not match migration target.',
      );
      exitCode = 1;
      return;
    }
  }

  final client = http.Client();
  String? accessToken;
  try {
    final auth = _mapResponse(
      await _jsonRequest(
        client,
        _endpoint(url, '/auth/v1/signup'),
        method: 'POST',
        headers: _headers(anonKey),
        body: smokeEmail.isEmpty
            ? <String, Object?>{'data': <String, Object?>{}}
            : <String, Object?>{
                'email': smokeEmail,
                'password': smokePassword,
              },
      ),
      smokeEmail.isEmpty ? 'Anonymous signup' : 'Smoke account signup',
    );
    accessToken = _requiredString(auth, 'access_token');
    final user = auth['user'];
    if (user is! Map<String, dynamic> || _requiredString(user, 'id').isEmpty) {
      throw StateError('Anonymous signup returned no user identity');
    }
    final headers = _headers(anonKey, accessToken);

    var spotId = requestedSpotId;
    late double spotLatitude;
    late double spotLongitude;
    if (spotId.isEmpty) {
      final spots = await _jsonRequest(
        client,
        _endpoint(
          url,
          '/rest/v1/fishing_spots',
          <String, String>{
            'select': 'id,latitude,longitude,gameplay_radius_m',
            'active': 'eq.true',
            'verification_status': 'eq.verified',
            'public_access': 'eq.true',
            'limit': '1',
          },
        ),
        method: 'GET',
        headers: headers,
      );
      if (spots is! List || spots.isEmpty || spots.first is! Map) {
        throw StateError('No active verified public fishing spot is available');
      }
      final spot = (spots.first as Map).cast<String, dynamic>();
      spotId = _requiredString(spot, 'id');
      spotLatitude = (spot['latitude'] as num?)?.toDouble() ??
          (throw StateError('Fishing spot returned no latitude'));
      spotLongitude = (spot['longitude'] as num?)?.toDouble() ??
          (throw StateError('Fishing spot returned no longitude'));
    } else {
      final spot = await _jsonRequest(
        client,
        _endpoint(
          url,
          '/rest/v1/fishing_spots',
          <String, String>{
            'select': 'latitude,longitude,gameplay_radius_m',
            'id': 'eq.$spotId',
            'active': 'eq.true',
            'verification_status': 'eq.verified',
            'public_access': 'eq.true',
            'limit': '1',
          },
        ),
        method: 'GET',
        headers: headers,
      );
      if (spot is! List || spot.isEmpty || spot.first is! Map) {
        throw StateError(
            'Requested active verified fishing spot is unavailable');
      }
      final row = (spot.first as Map).cast<String, dynamic>();
      spotLatitude = (row['latitude'] as num?)?.toDouble() ??
          (throw StateError('Fishing spot returned no latitude'));
      spotLongitude = (row['longitude'] as num?)?.toDouble() ??
          (throw StateError('Fishing spot returned no longitude'));
    }

    final firstStart = _mapResponse(
      await _jsonRequest(
        client,
        _endpoint(url, '/rest/v1/rpc/start_virtual_fishing_session'),
        method: 'POST',
        headers: headers,
        body: <String, Object?>{
          'p_spot_id': spotId,
          'p_lure_id': 'basic_bait',
          'p_fish_id': 'fish-001',
          'p_player_latitude': spotLatitude,
          'p_player_longitude': spotLongitude,
          'p_accuracy_m': 10.0,
        },
      ),
      'Fishing session start',
    );
    final earlySessionId = _requiredString(firstStart, 'session_id');
    final resolveUri =
        _endpoint(url, '/rest/v1/rpc/resolve_virtual_fishing_session');
    await _expectEarlyPullMiss(client, resolveUri, headers, earlySessionId);

    final start = _mapResponse(
      await _jsonRequest(
        client,
        _endpoint(url, '/rest/v1/rpc/start_virtual_fishing_session'),
        method: 'POST',
        headers: headers,
        body: <String, Object?>{
          'p_spot_id': spotId,
          'p_lure_id': 'basic_bait',
          'p_fish_id': 'fish-001',
          'p_player_latitude': spotLatitude,
          'p_player_longitude': spotLongitude,
          'p_accuracy_m': 10.0,
        },
      ),
      'Successful fishing session start',
    );
    final sessionId = _requiredString(start, 'session_id');
    final fishId = _requiredString(start, 'fish_id');
    final biteDelayMs = int.tryParse(start['bite_delay_ms']?.toString() ?? '');
    if (biteDelayMs == null || biteDelayMs < 1) {
      throw StateError('Fishing session returned an invalid bite delay');
    }

    await Future<void>.delayed(Duration(milliseconds: biteDelayMs + 200));
    final resolved = _mapResponse(
      await _jsonRequest(
        client,
        resolveUri,
        method: 'POST',
        headers: headers,
        body: <String, Object?>{
          'p_session_id': sessionId,
          'p_pull_elapsed_ms': biteDelayMs + 200,
        },
      ),
      'Fishing session resolve',
    );
    if (resolved['success'] != true ||
        resolved['status'] != 'resolved_success') {
      throw StateError(
          'Fishing session did not resolve inside the bite window');
    }
    if (resolved['session_id']?.toString() != sessionId ||
        fishId != 'fish-001') {
      throw StateError('Fishing session response lost its server binding');
    }

    final replay = _mapResponse(
      await _jsonRequest(
        client,
        resolveUri,
        method: 'POST',
        headers: headers,
        body: <String, Object?>{
          'p_session_id': sessionId,
          'p_pull_elapsed_ms': biteDelayMs + 200,
        },
      ),
      'Fishing session idempotent resolve',
    );
    if (replay['already_resolved'] != true || replay['success'] != true) {
      throw StateError('Resolved fishing session was not idempotent');
    }

    final claim = _mapResponse(
      await _jsonRequest(
        client,
        _endpoint(url, '/rest/v1/rpc/claim_gameplay_reward_ticket'),
        method: 'POST',
        headers: headers,
        body: <String, Object?>{
          'p_reward_kind': 'virtual_catch',
          'p_requested_amount': 1,
          'p_claim_key':
              'hosted-gameplay-smoke-${DateTime.now().toUtc().millisecondsSinceEpoch}',
          'p_fish_id': fishId,
          'p_gameplay_session_id': sessionId,
        },
      ),
      'Gameplay reward claim',
    );
    if (claim['claimed'] != true || (claim['reward_coins'] as num?) == null) {
      throw StateError('Server gameplay reward ticket was not claimed');
    }

    stdout.writeln(
      'PASS: hosted fishing session verified at spot $spotId; '
      'early pull became a miss, bite resolved, replay stayed idempotent, '
      'and reward ticket claimed.',
    );
  } catch (error) {
    stderr.writeln('FAIL: Supabase gameplay session smoke failed: $error');
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
          throw _HttpFailure('DELETE', response.statusCode, '/auth/v1/user');
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
          stderr.writeln('WARN: gameplay smoke sign-out failed: $error');
        }
      }
    }
    client.close();
  }
}
