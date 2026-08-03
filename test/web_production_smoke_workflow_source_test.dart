import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production Web smoke workflow verifies aliases and browser gameplay',
      () {
    final workflow = File(
      '.github/workflows/web-production-smoke.yml',
    ).readAsStringSync();

    expect(workflow, contains('workflow_dispatch:'));
    expect(workflow, contains('release_id:'));
    expect(workflow, contains('enforce_frame_budget:'));
    expect(workflow, contains('environment: fishergo-web-release'));
    expect(workflow, contains('https://fisher-go.app'));
    expect(workflow, contains('https://www.fisher-go.app'));
    expect(workflow, contains('tool/verify_deployed_web.dart'));
    expect(workflow, contains('tool/run_web_map_benchmark.js'));
    expect(workflow, contains('--enforce-bootstrap-budget'));
    expect(workflow,
        contains('--golden-manifest=test/goldens/game_map/manifest.json'));
    expect(workflow, contains('playwright install --with-deps chromium'));
    expect(workflow, contains('npm ci'));
    expect(workflow, contains('actions/upload-artifact@v4'));
    expect(workflow, contains('if: always()'));
    expect(workflow, contains('output/playwright/web-map-proof-390x844.png'));
    expect(workflow, contains('output/playwright/web-map-proof-1440x900.png'));
  });
}
