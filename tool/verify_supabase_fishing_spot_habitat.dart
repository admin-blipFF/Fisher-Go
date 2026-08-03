import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const _operationTimeout = Duration(seconds: 20);

Uri _endpoint(String baseUrl, String path,
    [Map<String, String>? queryParameters]) {
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

Map<String, String> _headers(String anonKey) => <String, String>{
      'apikey': anonKey,
      'Authorization': 'Bearer $anonKey',
      'Accept': 'application/json',
    };

class _HttpFailure implements Exception {
  const _HttpFailure(this.statusCode, this.path);

  final int statusCode;
  final String path;

  @override
  String toString() => 'GET $path returned HTTP $statusCode';
}

Future<Object?> _jsonGet(
  http.Client client,
  Uri uri,
  Map<String, String> headers,
) async {
  final response =
      await client.get(uri, headers: headers).timeout(_operationTimeout);
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw _HttpFailure(response.statusCode, uri.path);
  }
  return jsonDecode(response.body);
}

class _ExpectedHabitat {
  const _ExpectedHabitat(this.id, this.tags, this.weights);

  final String id;
  final List<String> tags;
  final Map<String, num> weights;
}

const _expectedHabitats = <_ExpectedHabitat>[
  _ExpectedHabitat(
      'P017', ['tung-chung-runway'], {'fish-103': 4, 'fish-109': 4}),
  _ExpectedHabitat(
      'P018', ['tung-chung-runway'], {'fish-103': 4, 'fish-109': 4}),
  _ExpectedHabitat('P035', [
    'east-water'
  ], {
    'fish-101': 4,
    'fish-103': 4,
    'fish-140': 4,
  }),
  _ExpectedHabitat('P036', [
    'east-water'
  ], {
    'fish-101': 4,
    'fish-103': 4,
    'fish-140': 4,
  }),
  _ExpectedHabitat('P043', [
    'east-water'
  ], {
    'fish-101': 4,
    'fish-103': 4,
    'fish-140': 4,
  }),
  _ExpectedHabitat('P045', [
    'sam-mun-tsai-tai-po-inner'
  ], {
    'fish-063': 4,
    'fish-067': 4,
  }),
  _ExpectedHabitat('P046', [
    'sam-mun-tsai-tai-po-inner'
  ], {
    'fish-063': 4,
    'fish-067': 4,
  }),
  _ExpectedHabitat('P047', [
    'sam-mun-tsai-tai-po-inner'
  ], {
    'fish-063': 4,
    'fish-067': 4,
  }),
  _ExpectedHabitat('P050', [
    'sam-mun-tsai-tai-po-inner'
  ], {
    'fish-063': 4,
    'fish-067': 4,
  }),
  _ExpectedHabitat('P051', [
    'tsing-ma-waters'
  ], {
    'fish-069': 4,
    'fish-073': 4,
  }),
  _ExpectedHabitat('P052', [
    'tsing-ma-waters'
  ], {
    'fish-069': 4,
    'fish-073': 4,
  }),
  _ExpectedHabitat('P053', [
    'tsing-ma-waters'
  ], {
    'fish-069': 4,
    'fish-073': 4,
  }),
  _ExpectedHabitat('P054', [
    'tsing-ma-waters'
  ], {
    'fish-069': 4,
    'fish-073': 4,
  }),
];

String _requiredString(Map<String, dynamic> row, String key) {
  final value = row[key]?.toString().trim() ?? '';
  if (value.isEmpty) throw StateError('Row did not include $key');
  return value;
}

void _verifyRow(Map<String, dynamic> row, _ExpectedHabitat expected) {
  if (_requiredString(row, 'id') != expected.id) {
    throw StateError('Unexpected fishing spot row');
  }
  final tags =
      (row['habitat_tags'] as List?)?.whereType<String>().toSet() ?? <String>{};
  for (final tag in expected.tags) {
    if (!tags.contains(tag)) {
      throw StateError('${expected.id} is missing habitat tag $tag');
    }
  }
  final rawWeights = row['species_weights'];
  if (rawWeights is! Map) {
    throw StateError('${expected.id} has no species weights');
  }
  for (final entry in expected.weights.entries) {
    final actual = rawWeights[entry.key];
    if (actual is! num || actual != entry.value) {
      throw StateError(
        '${expected.id} has invalid weight for ${entry.key}',
      );
    }
  }
}

Future<void> main() async {
  final url = Platform.environment['SUPABASE_URL']?.trim() ?? '';
  final anonKey = Platform.environment['SUPABASE_ANON_KEY']?.trim() ?? '';
  final projectRef = Platform.environment['SUPABASE_PROJECT_REF']?.trim() ?? '';
  final expectedProjectRef =
      Platform.environment['SUPABASE_EXPECTED_PROJECT_REF']?.trim() ?? '';
  final missing = <String>[
    if (url.isEmpty) 'SUPABASE_URL',
    if (anonKey.isEmpty) 'SUPABASE_ANON_KEY',
    if (expectedProjectRef.isNotEmpty && projectRef.isEmpty)
      'SUPABASE_PROJECT_REF',
  ];
  if (missing.isNotEmpty) {
    stderr.writeln(
      'SKIP: fishing-spot habitat smoke needs ${missing.join(', ')}.',
    );
    exitCode = 2;
    return;
  }

  try {
    final hostProjectRef = Uri.parse(url).host.split('.').first;
    if (projectRef.isNotEmpty && hostProjectRef != projectRef) {
      throw StateError(
          'Supabase URL project ref does not match configured ref');
    }
    if (expectedProjectRef.isNotEmpty && projectRef != expectedProjectRef) {
      throw StateError(
          'Configured project ref does not match migration target');
    }

    final client = http.Client();
    try {
      final ids = _expectedHabitats.map((item) => item.id).join(',');
      final response = await _jsonGet(
        client,
        _endpoint(
          url,
          '/rest/v1/fishing_spots',
          <String, String>{
            'select': 'id,habitat_tags,species_weights',
            'id': 'in.($ids)',
            'active': 'eq.true',
            'verification_status': 'eq.verified',
            'public_access': 'eq.true',
          },
        ),
        _headers(anonKey),
      );
      if (response is! List) {
        throw StateError('Fishing-spot response was not a JSON array');
      }
      final rows = <String, Map<String, dynamic>>{
        for (final item in response)
          if (item is Map) item['id'].toString(): item.cast<String, dynamic>(),
      };
      for (final expected in _expectedHabitats) {
        final row = rows[expected.id];
        if (row == null) {
          throw StateError('${expected.id} is missing from public registry');
        }
        _verifyRow(row, expected);
      }
      stdout.writeln(
        'PASS: verified ${_expectedHabitats.length} hosted fishing-spot '
        'habitat profiles by stable fish ID.',
      );
    } finally {
      client.close();
    }
  } catch (error) {
    stderr.writeln(
        'FAIL: hosted fishing-spot habitat verification failed: $error');
    exitCode = 1;
  }
}
