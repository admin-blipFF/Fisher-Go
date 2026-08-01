import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> readVercelConfig() => jsonDecode(
        File('vercel.json').readAsStringSync(),
      ) as Map<String, dynamic>;

  Map<String, String> cacheHeaders() {
    final config = readVercelConfig();
    final entries = config['headers'] as List<dynamic>;
    return <String, String>{
      for (final entry in entries)
        (entry as Map<String, dynamic>)['source'] as String:
            ((entry['headers'] as List<dynamic>).single
                as Map<String, dynamic>)['value'] as String,
    };
  }

  test('release entrypoints always revalidate at the CDN boundary', () {
    final headers = cacheHeaders();
    const noCache = 'no-cache, no-store, must-revalidate';

    for (final source in [
      '/',
      '/index.html',
      '/manifest.json',
      '/flutter_bootstrap.js',
      '/flutter_service_worker.js',
      '/flutter.js',
      '/maplibre_render_tuning.js',
      '/version.json',
      '/release-manifest.json',
    ]) {
      expect(headers[source], noCache, reason: source);
    }
  });

  test('build-id versioned Dart code is the only immutable app payload', () {
    final headers = cacheHeaders();

    expect(headers['/main.dart.js'], 'public, max-age=31536000, immutable');
    expect(headers['/assets/(.*)'], 'public, max-age=0, must-revalidate');
    expect(headers['/canvaskit/(.*)'], 'public, max-age=0, must-revalidate');
    expect(headers['/favicon.png'],
        'public, max-age=86400, stale-while-revalidate=604800');
    expect(headers['/icons/(.*)'],
        'public, max-age=86400, stale-while-revalidate=604800');
  });
}
