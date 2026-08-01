import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('manual Web benchmark workflow keeps reproducible visual evidence', () {
    final workflow =
        File('.github/workflows/web-map-benchmark.yml').readAsStringSync();

    expect(workflow, contains('workflow_dispatch:'));
    expect(workflow, contains('enforce_frame_budget'));
    expect(workflow, contains('flutter build web --release --no-pub'));
    expect(workflow, contains('FISHERGO_MAPLIBRE=true'));
    expect(workflow, contains('FISHERGO_MAP_PERF=true'));
    final package = File('package.json').readAsStringSync();
    expect(package, contains('"playwright": "1.55.0"'));
    expect(workflow, contains('npm ci'));
    expect(workflow, contains('playwright install --with-deps chromium'));
    expect(workflow, contains('python3 -m http.server 4173'));
    expect(workflow, contains('tool/run_web_map_benchmark.js'));
    expect(workflow, contains('--golden-manifest=test/goldens/game_map/manifest.json'));
    expect(workflow, contains('tmp/web-map-benchmark-ci.json'));
    expect(workflow, contains('output/playwright/web-map-proof-390x844.png'));
    expect(workflow, contains('output/playwright/web-map-proof-1440x900.png'));
    expect(workflow, contains('actions/upload-artifact@v4'));
    expect(workflow, contains('if: always()'));
  });
}
