import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('manual Android map benchmark workflow preserves performance evidence',
      () {
    final workflow = File(
      '.github/workflows/android-map-benchmark.yml',
    ).readAsStringSync();

    expect(workflow, contains('workflow_dispatch:'));
    expect(workflow, contains('runs-on: ubuntu-latest'));
    expect(workflow, contains('reactivecircus/android-emulator-runner@v2'));
    expect(workflow, contains('api-level: 35'));
    expect(workflow, contains('arch: x86_64'));
    expect(workflow, contains('emulator-options: -no-window -gpu host'));
    expect(workflow, contains('flutter build apk --profile --no-pub'));
    expect(workflow, contains('--dart-define=FISHERGO_MAPLIBRE=true'));
    expect(workflow, contains('--dart-define=FISHERGO_MAP_PERF=true'));
    expect(workflow, contains('tool/android_map_benchmark.ps1'));
    expect(workflow, contains('-DeviceSerial emulator-5554'));
    expect(workflow, contains('-RequireHostGpu'));
    expect(workflow, contains('-RequireMapReadiness'));
    expect(workflow, contains('-WarmupRounds 1'));
    expect(workflow, contains('enforce_frame_budget'));
    expect(workflow, contains('-EnforceFrameBudget'));
    expect(workflow, contains('-OutputPath tmp/android-map-benchmark-ci.json'));
    expect(workflow, contains('actions/upload-artifact@v4'));
    expect(workflow, contains('if: always()'));
    expect(workflow, contains('tmp/android-map-benchmark-ci.json'));
    expect(workflow, contains('tmp/android-map-benchmark-ci.png'));
  });
}
