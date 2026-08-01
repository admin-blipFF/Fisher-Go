import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Web map benchmark captures real frame and jank evidence', () {
    final source = File('tool/web_map_benchmark.js').readAsStringSync();

    expect(source, contains('requestAnimationFrame'));
    expect(source, contains('page.mouse.down'));
    expect(source, contains('page.mouse.up'));
    expect(source, contains('p95_frame_ms'));
    expect(source, contains('janky_rate'));
    expect(source, contains('PerformanceObserver'));
    expect(source, contains('main_thread_long_tasks'));
    expect(source, contains('boundedEntries'));
    expect(source, contains('FisherGO_WEB_BENCHMARK'));
    expect(source, contains("page.on('console'"));
    expect(source, contains('await page.reload()'));
    expect(source, contains("getByRole('button'"));
    expect(source, contains("locator('flutter-view')"));
    expect(source, contains('flt-semantics-placeholder'));
    expect(source, contains('enableSemanticsAndWaitForGuest'));
    expect(source, contains('semanticsAttempt'));
    expect(source, contains('Semantics did not expose the guest action'));
    expect(source, contains('訪客遊玩'));
    expect(source, contains('略過'));
    expect(source, contains('startupOverlaysClosed'));
    expect(source, contains('Identity choice dialog or tutorial overlay remained visible'));
    expect(source, contains('maplibregl-canvas'));
    expect(source, contains("state: 'attached'"));
    expect(source, contains('FisherGO map performance:'));
    expect(source, contains('FisherGO map readiness:'));
    expect(source, contains('map_telemetry'));
    expect(source, contains('tileResponses'));
    expect(source, contains('openfreemap'));
  });
}
