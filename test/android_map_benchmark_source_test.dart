import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android map benchmark enforces the emulator-only repeatable flow', () {
    final source = File('tool/android_map_benchmark.ps1').readAsStringSync();

    expect(source, contains('android_smoke_preflight.ps1'));
    expect(source, contains(r'$powerShell = Get-Command pwsh'));
    expect(source,
        contains(r'$preflightOutput = & $powerShell.Source @preflightArgs'));
    expect(source, contains('A PowerShell launcher (pwsh or powershell)'));
    expect(source, isNot(contains('& powershell @preflightArgs')));
    expect(source, contains(r'[int]$MinimumApi = 35'));
    expect(source, contains('build/app/outputs/flutter-apk/app-profile.apk'));
    expect(source, contains('uninstall com.fishergo.app'));
    expect(source, contains(r'install $ApkPath'));
    expect(source, contains('pm grant com.fishergo.app'));
    expect(source, contains('android.permission.ACCESS_FINE_LOCATION'));
    expect(source, isNot(contains('android.permission.CAMERA')));
    expect(source, contains('emu geo fix 114.1874 22.3819'));
    expect(source, contains('uiautomator dump'));
    expect(source, contains('訪客遊玩'));
    expect(source, contains('略過'));
    expect(source, contains('Fisher Lv'));
    expect(source, contains('重新定位'));
    expect(source, contains(r"Tap-BenchmarkControl $locationUiXml '重新定位'"));
    expect(source, contains('GPS '));
    expect(source, contains(r'$locationDescription'));
    expect(source, contains('logcat -c'));
    expect(source, contains('com.fishergo.app'));
    expect(source, contains('dumpsys gfxinfo com.fishergo.app reset'));
    expect(source, contains(r'[int]$WarmupRounds = 0'));
    expect(source, contains(r'[switch]$SkipInstall'));
    expect(source, contains(r'[switch]$RequireHostGpu'));
    expect(source, contains(r'[switch]$RequireMapReadiness'));
    expect(source, contains(r'[switch]$AllowHudlessGameHome'));
    expect(source, contains('Showing a Map created with MapLibre'));
    expect(source, contains('map_readiness_observed'));
    expect(source, contains('Map readiness telemetry was required'));
    expect(source, contains(r'[int]$MaxP95Ms = 20'));
    expect(source, contains(r'[int]$MinimumFrameCount = 60'));
    expect(source, contains(r'[switch]$EnforceFrameBudget'));
    expect(source, contains('pm path com.fishergo.app'));
    expect(
      source,
      contains(r'if ([string]::IsNullOrWhiteSpace($installedPackage))'),
    );
    expect(
      source,
      contains(r'if ([string]::IsNullOrWhiteSpace($xml))'),
    );
    expect(source, contains('uiautomator_retry_count'));
    expect(source, contains(r"$ErrorActionPreference = 'Continue'"));
    expect(source, contains(r'skip_install = [bool]$SkipInstall'));
    expect(
      source,
      contains(r'for ($round = 0; $round -lt $WarmupRounds; $round++)'),
    );
    expect(source, contains(r'warmup_rounds = $WarmupRounds'));
    expect(source, contains('Total frames rendered'));
    expect(source, contains('95th percentile'));
    expect(source, contains('slow_draw_commands'));
    expect(source, contains(r'$gfxTraceValid'));
    expect(source, contains(r'$totalFrames -ge $MinimumFrameCount'));
    expect(source, contains('gfx_trace_valid'));
    expect(source, contains('minimum_frame_count'));
    expect(source, contains('max_p95_ms'));
    expect(source, contains('frame_budget_passed'));
    expect(source, contains('Frame budget gate requires a p95 metric'));
    expect(source, contains('Frame budget exceeded'));
    expect(source, contains('did not produce a valid gfxinfo frame trace'));
    expect(source, contains('minimum frame count'));
    expect(source, contains('FisherGO (map|fallback) performance'));
    expect(source, contains("'FisherGO (map|fallback) performance:'"));
    expect(source, contains('flutter_p95_total_ms'));
    expect(source, contains('flutter_p50_vsync_overhead_ms'));
    expect(source, contains('flutter_p95_vsync_overhead_ms'));
    expect(source, contains('flutter_p50_frame_gap_ms'));
    expect(source, contains('flutter_p95_frame_gap_ms'));
    expect(source, contains('FisherGO map readiness'));
    expect(source, contains('readiness_style_ready_ms'));
    expect(source, contains('readiness_map_idle_ms'));
    expect(source, contains('dumpsys activity processes com.fishergo.app'));
    expect(source, contains('mNotResponding=true'));
    expect(source, contains('anr_detected'));
    expect(source, contains('ConvertTo-Json'));
    expect(source, contains('dumpsys SurfaceFlinger'));
    expect(source, contains('SwiftShader'));
    expect(source, contains('ANDROID_GPU_RENDERER'));
  });
}
