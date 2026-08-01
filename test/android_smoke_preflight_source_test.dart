import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android smoke preflight can grant runtime permissions after API gating',
      () {
    final source = File('tool/android_smoke_preflight.ps1').readAsStringSync();

    expect(source, contains('[switch]\$GrantRuntimePermissions'));
    expect(source, contains("\$KnownInvalidSerial = '0123456789ABCDEF'"));
    expect(source, contains("\$MinimumApi = 35"));
    expect(source, contains('android.permission.ACCESS_FINE_LOCATION'));
    expect(source, isNot(contains('android.permission.CAMERA')));
  });

  test('Android smoke runner forwards the selected API 35 emulator to Flutter',
      () {
    final source =
        File('tool/run_android_integration_smoke.ps1').readAsStringSync();

    expect(source, contains('android_smoke_preflight.ps1'));
    expect(source, contains('-GrantRuntimePermissions'));
    expect(source, contains('integration_test/\$SmokeTestFile'));
    expect(source, contains('location_permission_denied_flow_test.dart'));
    expect(source, contains('location_service_disabled_flow_test.dart'));
    expect(source, contains('app_resume_flow_test.dart'));
    expect(source, contains('panorama_map_flow_test.dart'));
    expect(source, contains('test --no-pub'));
    expect(source, contains('map_rotation_flow_test.dart'));
    expect(source, contains('map_spot_selection_flow_test.dart'));
    expect(source, contains('offline_network_toggle_flow_test.dart'));
    expect(source, contains('[switch]\$ClearAppData'));
    expect(source, contains('[switch]\$ToggleNetwork'));
    expect(source, contains('[double]\$GeoLongitude = 114.1874'));
    expect(source, contains('[double]\$GeoLatitude = 22.3819'));
    expect(source, contains('emu geo fix'));
    expect(source, contains('PermissionProfile'));
    expect(source, contains('deny-location'));
    expect(source, contains('location-disabled'));
    expect(source, contains('limited-photo'));
    expect(source, contains('READ_MEDIA_VISUAL_USER_SELECTED'));
    expect(source, contains('READ_MEDIA_IMAGES'));
    expect(source, contains('pm set-permission-flags'));
    expect(source, contains('set-location-enabled'));
    expect(source, contains('airplane-mode enable'));
    expect(source, contains('airplane-mode disable'));
    expect(source, contains('svc wifi disable'));
    expect(source, contains('svc wifi enable'));
    expect(source, contains('svc data disable'));
    expect(source, contains('svc data enable'));
    expect(source, contains('Start-Sleep -Seconds 15'));
    expect(source, contains('build apk --debug'));
    expect(source, contains('--dart-define=FISHERGO_MAPLIBRE=true'));
    expect(source, contains('install -r'));
    expect(
      source,
      contains('GrantRuntimePermissions'),
    );
  });

  test('spot selection smoke requires an explicit verified-spot GPS override',
      () {
    final source =
        File('tool/run_android_integration_smoke.ps1').readAsStringSync();

    expect(
      source,
      contains(
        "map_spot_selection_flow_test.dart requires a verified-spot GPS override",
      ),
    );
    expect(source, contains('-GeoLongitude 114.109537072'));
    expect(source, contains('-GeoLatitude 22.354208013'));
  });

  test('Android smoke runner fails fast and prints timeout diagnostics', () {
    final source =
        File('tool/run_android_integration_smoke.ps1').readAsStringSync();

    expect(source, contains('[int]\$TimeoutSeconds = 180'));
    expect(source, contains('Wait-Job'));
    expect(source, contains('ANDROID_SMOKE_TIMEOUT'));
    expect(source, contains('ANDROID_SMOKE_FLUTTER_OUTPUT_BEGIN'));
    expect(source, contains('Receive-Job -Job \$job -ErrorAction Continue'));
    expect(source, contains('pm clear com.fishergo.app'));
    expect(source, contains('logcat -d'));
  });
}
