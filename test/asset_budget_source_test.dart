import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('asset manifest excludes the retired fixed-map background', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(pubspec, contains('    - assets/maps/hk_terrain_mvp.json'));
    expect(pubspec, contains('    - assets/maps/hk_overworld_overlay.png'));
    expect(pubspec, contains('    - assets/maps/textures/'));
    expect(pubspec, isNot(contains('    - assets/maps/\n')));
    expect(pubspec, isNot(contains('fishergo_overworld_imagegen_v3.png')));
  });

  test('Flutter quality workflow builds and budgets Android release output',
      () {
    final workflow =
        File('.github/workflows/flutter-quality.yml').readAsStringSync();

    expect(
      workflow,
      contains(
        'flutter build appbundle --release --no-pub\n'
        '          --dart-define=FISHERGO_MAPLIBRE=true\n'
        '          --dart-define=FISHERGO_RELEASE_ID=ci-\${{ github.run_id }}\n'
        '          --target-platform android-arm64',
      ),
    );
    expect(workflow, contains('- name: Format'));
    expect(
      workflow,
      contains('dart format --output=none --set-exit-if-changed'),
    );
    expect(
      workflow,
      contains(
        'dart run tool/check_client_artifacts_for_secrets.dart '
        'build/web build/app/outputs',
      ),
    );
    expect(workflow, contains('tool/check_asset_budget.dart'));
    expect(workflow, contains('--android-output-root=build/app/outputs'));
    expect(workflow, contains('--packaged-asset-root=build/web/assets'));
    expect(workflow, contains('android-integration:'));
    expect(workflow, contains('reactivecircus/android-emulator-runner@v2'));
    expect(workflow, contains('api-level: 35'));
    expect(
      workflow,
      contains('pwsh -NoProfile -File tool/run_android_integration_smoke.ps1'),
    );
    expect(workflow, contains('-ClearAppData'));
    expect(workflow, contains('-TimeoutSeconds 240'));
    expect(workflow, contains('-TestFile startup_auth_flow_test.dart'));
    expect(workflow, contains('-TestFile app_resume_flow_test.dart'));
    expect(workflow, contains('-TestFile panorama_map_flow_test.dart'));
    expect(workflow, contains('-TestFile fishing_minigame_flow_test.dart'));
    expect(workflow, contains('-TestFile offline_reconnect_flow_test.dart'));
    expect(
        workflow, contains('-TestFile offline_network_toggle_flow_test.dart'));
    expect(workflow, contains('-TestFile daily_task_reward_flow_test.dart'));
    expect(workflow,
        contains('-TestFile location_permission_denied_flow_test.dart'));
    expect(workflow,
        contains('-TestFile location_service_disabled_flow_test.dart'));
    expect(workflow,
        contains('-TestFile limited_photo_permission_flow_test.dart'));
  });
}
