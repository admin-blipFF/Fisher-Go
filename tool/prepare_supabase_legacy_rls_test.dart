import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const _operationTimeout = Duration(seconds: 20);
final _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
);

Uri _endpoint(String baseUrl, String path) {
  final base = baseUrl.endsWith('/')
      ? baseUrl.substring(0, baseUrl.length - 1)
      : baseUrl;
  return Uri.parse('$base$path');
}

Future<Map<String, dynamic>> _signIn(
  http.Client client, {
  required String url,
  required String anonKey,
  required String email,
  required String password,
}) async {
  final response = await client
      .post(
        _endpoint(url, '/auth/v1/token?grant_type=password'),
        headers: <String, String>{
          'apikey': anonKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, String>{
          'email': email,
          'password': password,
        }),
      )
      .timeout(_operationTimeout);
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw StateError(
      'Supabase RLS smoke sign-in failed with HTTP ${response.statusCode}',
    );
  }
  final decoded = jsonDecode(response.body);
  if (decoded is! Map<String, dynamic>) {
    throw StateError('Supabase RLS smoke sign-in returned invalid JSON');
  }
  return decoded;
}

String _requiredEnvironment(String name) =>
    Platform.environment[name]?.trim() ?? '';

String _outputPath(List<String> args) {
  for (final arg in args) {
    if (arg.startsWith('--output=')) {
      final path = arg.substring('--output='.length).trim();
      if (path.isNotEmpty) return path;
    }
  }
  return 'tmp/legacy_auth_rls_test.sql';
}

Future<void> main(List<String> args) async {
  final url = _requiredEnvironment('SUPABASE_URL');
  final anonKey = _requiredEnvironment('SUPABASE_ANON_KEY');
  final emailA = _requiredEnvironment('FISHERGO_RLS_USER_A_EMAIL');
  final passwordA = Platform.environment['FISHERGO_RLS_USER_A_PASSWORD'] ?? '';
  final emailB = _requiredEnvironment('FISHERGO_RLS_USER_B_EMAIL');
  final passwordB = Platform.environment['FISHERGO_RLS_USER_B_PASSWORD'] ?? '';
  final missing = <String>[
    if (url.isEmpty) 'SUPABASE_URL',
    if (anonKey.isEmpty) 'SUPABASE_ANON_KEY',
    if (emailA.isEmpty) 'FISHERGO_RLS_USER_A_EMAIL',
    if (passwordA.isEmpty) 'FISHERGO_RLS_USER_A_PASSWORD',
    if (emailB.isEmpty) 'FISHERGO_RLS_USER_B_EMAIL',
    if (passwordB.isEmpty) 'FISHERGO_RLS_USER_B_PASSWORD',
  ];
  if (missing.isNotEmpty) {
    stderr.writeln(
      'SKIP: legacy RLS smoke needs ${missing.join(', ')}.',
    );
    exitCode = 2;
    return;
  }

  final client = http.Client();
  try {
    final userA = await _signIn(
      client,
      url: url,
      anonKey: anonKey,
      email: emailA,
      password: passwordA,
    );
    final userB = await _signIn(
      client,
      url: url,
      anonKey: anonKey,
      email: emailB,
      password: passwordB,
    );
    final userAJson = userA['user'];
    final userBJson = userB['user'];
    final userAId =
        userAJson is Map<String, dynamic> ? userAJson['id'] as String? : null;
    final userBId =
        userBJson is Map<String, dynamic> ? userBJson['id'] as String? : null;
    if (userAId == null || !_uuidPattern.hasMatch(userAId)) {
      throw StateError('RLS smoke User A did not return a valid Auth UUID');
    }
    if (userBId == null || !_uuidPattern.hasMatch(userBId)) {
      throw StateError('RLS smoke User B did not return a valid Auth UUID');
    }
    if (userAId == userBId) {
      throw StateError('RLS smoke requires two different Auth users');
    }

    final template = File('tool/templates/legacy_auth_rls_test.sql');
    if (!template.existsSync()) {
      throw StateError('Missing legacy Auth RLS SQL template');
    }
    final rendered = template
        .readAsStringSync()
        .replaceAll('__FISHERGO_USER_A__', userAId)
        .replaceAll('__FISHERGO_USER_B__', userBId);
    if (rendered.contains('__FISHERGO_USER_')) {
      throw StateError('Legacy Auth RLS template has unresolved user markers');
    }
    final output = File(_outputPath(args));
    output.parent.createSync(recursive: true);
    output.writeAsStringSync(rendered);
    stdout.writeln(
      'PASS: prepared transaction-only legacy RLS fixture for two Auth users.',
    );
  } catch (error) {
    stderr.writeln('FAIL: could not prepare legacy RLS fixture: $error');
    exitCode = 1;
  } finally {
    client.close();
  }
}
