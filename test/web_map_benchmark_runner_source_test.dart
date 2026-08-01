import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Web benchmark runner publishes and enforces both viewport metrics', () {
    final source = File('tool/run_web_map_benchmark.js').readAsStringSync();

    expect(source, contains("require('playwright')"));
    expect(source, contains("require('node:zlib')"));
    expect(source, contains('chromium.launch'));
    expect(source, contains('browser.newContext'));
    expect(source, contains('geolocation:'));
    expect(source, contains("permissions: ['geolocation']"));
    expect(source, contains('22.3819'));
    expect(source, contains('114.1874'));
    expect(source, contains('390x844'));
    expect(source, contains('1440x900'));
    expect(source, contains('FisherGO_WEB_BENCHMARK:'));
    expect(source, contains('p95_frame_ms'));
    expect(source, contains('janky_rate'));
    expect(source, contains('--enforce-frame-budget'));
    expect(source, contains('frame_budget_passed'));
    expect(source, contains('inspectMapScreenshot'));
    expect(source, contains('map_visual_proof'));
    expect(source, contains('golden_visual_proof'));
    expect(source, contains('test/goldens/game_map/manifest.json'));
    expect(source, contains('--golden-manifest'));
    expect(source, contains('readGoldenManifest'));
    expect(source, contains('adjacent_change_ratio'));
    expect(source, contains('map visual proof is not populated'));
    expect(source, contains('web-map-proof-\${viewportValue}.png'));
  });
}
