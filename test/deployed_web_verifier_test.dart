import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../tool/verify_deployed_web.dart';

const _revalidatingCacheControl = 'no-cache, no-store, must-revalidate';
const _immutableCacheControl = 'public, max-age=31536000, immutable';

class _FakeClient extends http.BaseClient {
  _FakeClient(this._responses);

  final Map<String, http.Response> _responses;
  final requested = <Uri>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requested.add(request.url);
    final response = _responses[request.url.toString()];
    if (response == null) {
      return http.StreamedResponse(const Stream<List<int>>.empty(), 404);
    }
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(response.body)),
      response.statusCode,
      headers: response.headers,
      request: request,
    );
  }
}

void main() {
  test('passes when aliases serve the same Flutter bootstrap and no env asset',
      () async {
    final aliases = [
      Uri.parse('https://fisher-go.app'),
      Uri.parse('https://www.fisher-go.app'),
    ];
    final body =
        '<base href="/">\n<script src="flutter_bootstrap.js" async></script>';
    final responses = <String, http.Response>{};
    for (final alias in aliases) {
      responses[alias.toString()] = http.Response(
        body,
        200,
        headers: const {'cache-control': _revalidatingCacheControl},
      );
      responses['${alias.origin}/flutter_bootstrap.js'] = http.Response(
        '{"mainJsPath":"main.dart.js?v=stable"}',
        200,
        headers: const {'cache-control': _revalidatingCacheControl},
      );
      responses['${alias.origin}/main.dart.js?v=stable'] = http.Response(
        'main',
        200,
        headers: const {'cache-control': _immutableCacheControl},
      );
      responses['${alias.origin}/assets/.env'] = http.Response('', 404);
      responses['${alias.origin}/release-manifest.json'] = http.Response(
        '{"release_id":"release-1","app_version":"0.1.0+1",'
        '"build_id":"build-1","build_time":"now","git_sha":"unknown"}',
        200,
        headers: const {'cache-control': _revalidatingCacheControl},
      );
    }

    final result = await verifyDeployedWeb(
      aliases: aliases,
      client: _FakeClient(responses),
    );

    expect(result.passed, isTrue);
    expect(result.errors, isEmpty);
  });

  test('rejects a missing Flutter bootstrap and an exposed env asset',
      () async {
    final alias = Uri.parse('https://fisher-go.app');
    final client = _FakeClient({
      alias.toString(): http.Response('<html>not flutter</html>', 200),
      'https://fisher-go.app/assets/.env': http.Response('SECRET', 200),
      'https://fisher-go.app/release-manifest.json': http.Response('', 404),
    });
    final result = await verifyDeployedWeb(
      aliases: [alias],
      client: client,
    );

    expect(result.passed, isFalse);
    expect(client.requested.map((uri) => uri.toString()), [
      'https://fisher-go.app',
      'https://fisher-go.app/assets/.env',
      'https://fisher-go.app/release-manifest.json',
    ]);
    expect(result.errors, contains(contains('Flutter bootstrap')));
    expect(result.errors, contains(contains('/assets/.env')));
  });

  test('rejects aliases with different bootstrap signatures', () async {
    final first = Uri.parse('https://fisher-go.app');
    final second = Uri.parse('https://www.fisher-go.app');
    final result = await verifyDeployedWeb(
      aliases: [first, second],
      client: _FakeClient({
        first.toString():
            http.Response('<script src="flutter_bootstrap.js"></script>', 200),
        second.toString():
            http.Response('<script src="flutter_bootstrap.js"></script>', 200),
        '${first.origin}/flutter_bootstrap.js': http.Response(
          '{"mainJsPath":"main.dart.js?v=one"}',
          200,
        ),
        '${second.origin}/flutter_bootstrap.js': http.Response(
          '{"mainJsPath":"main.dart.js?v=two"}',
          200,
        ),
        '${first.origin}/assets/.env': http.Response('', 404),
        '${second.origin}/assets/.env': http.Response('', 404),
        '${first.origin}/release-manifest.json': http.Response(
          '{"release_id":"release-1","app_version":"0.1.0+1",'
          '"build_id":"build-1","build_time":"now","git_sha":"unknown"}',
          200,
        ),
        '${second.origin}/release-manifest.json': http.Response(
          '{"release_id":"release-2","app_version":"0.1.0+1",'
          '"build_id":"build-2","build_time":"now","git_sha":"unknown"}',
          200,
        ),
      }),
    );

    expect(result.passed, isFalse);
    expect(result.errors, contains(contains('same Flutter bootstrap')));
    expect(result.errors, contains(contains('same release manifest')));
  });

  test('rejects a public alias serving an unexpected release id', () async {
    final alias = Uri.parse('https://fisher-go.app');
    final client = _FakeClient({
      alias.toString():
          http.Response('<script src="flutter_bootstrap.js"></script>', 200),
      'https://fisher-go.app/flutter_bootstrap.js': http.Response(
        '{"mainJsPath":"main.dart.js?v=old"}',
        200,
      ),
      'https://fisher-go.app/assets/.env': http.Response('', 404),
      'https://fisher-go.app/release-manifest.json': http.Response(
        '{"release_id":"release-old","app_version":"0.1.0+1",'
        '"build_id":"build-old","build_time":"now","git_sha":"old"}',
        200,
      ),
    });

    final result = await verifyDeployedWeb(
      aliases: [alias],
      expectedReleaseId: 'release-new',
      client: client,
    );

    expect(result.passed, isFalse);
    expect(result.errors, contains(contains('release-new')));
  });

  test('identifies Vercel deployment protection before asset checks', () async {
    final alias = Uri.parse('https://preview.fishergo.app');
    final client = _FakeClient({
      alias.toString(): http.Response(
        '<html data-dpl-id="dpl_preview"><head>'
        '<link href="/_next/static/chunks/protection.css">'
        '</head></html>',
        200,
      ),
    });

    final result = await verifyDeployedWeb(
      aliases: [alias],
      client: client,
    );

    expect(result.passed, isFalse);
    expect(result.errors, contains(contains('Deployment Protection')));
    expect(client.requested, [alias]);
  });

  test('rejects stale cache headers on a public release', () async {
    final alias = Uri.parse('https://fisher-go.app');
    final client = _FakeClient({
      alias.toString():
          http.Response('<script src="flutter_bootstrap.js"></script>', 200),
      'https://fisher-go.app/flutter_bootstrap.js': http.Response(
        '{"mainJsPath":"main.dart.js?v=release-1"}',
        200,
      ),
      'https://fisher-go.app/main.dart.js?v=release-1': http.Response(
        'main',
        200,
        headers: const {
          'cache-control': 'public, max-age=0, must-revalidate',
        },
      ),
      'https://fisher-go.app/assets/.env': http.Response('', 404),
      'https://fisher-go.app/release-manifest.json': http.Response(
        '{"release_id":"release-1","app_version":"0.1.0+1",'
        '"build_id":"build-1","build_time":"now","git_sha":"unknown"}',
        200,
      ),
    });

    final result = await verifyDeployedWeb(
      aliases: [alias],
      client: client,
    );

    expect(result.passed, isFalse);
    expect(result.errors, contains(contains('Cache-Control')));
  });
}
