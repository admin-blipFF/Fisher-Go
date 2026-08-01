import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('API 35 CI smoke workflow fails fast and covers the vertical slice',
      () {
    final workflow =
        File('.github/workflows/flutter-quality.yml').readAsStringSync();

    expect(workflow, contains('api-level: 35'));
    expect(workflow, contains('arch: x86_64'));
    expect(workflow, contains('set -euo pipefail'));
    expect(workflow, contains('-DeviceSerial emulator-5554'));
    expect(workflow, contains('-GeoLongitude 114.109537072'));
    expect(workflow, contains('-GeoLatitude 22.354208013'));
    expect(workflow, contains('-ToggleNetwork'));
    expect(workflow, contains('-PermissionProfile deny-location'));
    expect(workflow, contains('-PermissionProfile location-disabled'));
    expect(workflow, contains('-PermissionProfile limited-photo'));

    const requiredFlows = [
      'startup_auth_flow_test.dart',
      'app_resume_flow_test.dart',
      'panorama_map_flow_test.dart',
      'map_rotation_flow_test.dart',
      'map_spot_selection_flow_test.dart',
      'fishing_minigame_flow_test.dart',
      'offline_reconnect_flow_test.dart',
      'offline_network_toggle_flow_test.dart',
      'daily_task_reward_flow_test.dart',
      'location_permission_denied_flow_test.dart',
      'location_service_disabled_flow_test.dart',
      'limited_photo_permission_flow_test.dart',
    ];

    for (final flow in requiredFlows) {
      expect(workflow, contains('-TestFile $flow'), reason: flow);
    }
  });
}
