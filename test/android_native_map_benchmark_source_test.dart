import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native map benchmark isolates MapLibre from Flutter composition', () {
    final source =
        File('tool/android_native_map_benchmark.ps1').readAsStringSync();
    final activity = File(
      'android/app/src/profile/kotlin/com/fishergo/app/NativeMapProofActivity.kt',
    ).readAsStringSync();

    expect(source, contains('.NativeMapProofActivity'));
    expect(source, contains(r'$powerShell = Get-Command pwsh'));
    expect(source,
        contains(r'$preflightOutput = & $powerShell.Source @preflightArgs'));
    expect(source, contains('A PowerShell launcher (pwsh or powershell)'));
    expect(source, isNot(contains('& powershell @preflightArgs')));
    expect(
        source, contains('dumpsys SurfaceFlinger --timestats -clear -enable'));
    expect(source, contains('dumpsys SurfaceFlinger --timestats -dump'));
    expect(source, contains('present2present histogram is as below'));
    expect(source, contains('surfaceflinger_timestats_valid'));
    expect(source, contains('DisableTilePrefetch'));
    expect(source, contains('noTilePrefetch'));
    expect(source, contains('DisableBuildingExtrusion'));
    expect(source, contains('noBuildingExtrusion'));
    expect(source, contains('DisableLandcover'));
    expect(source, contains('noLandcover'));
    expect(source, contains('DisableFillAntialias'));
    expect(source, contains('noFillAntialias'));
    expect(source, contains('DisableRoads'));
    expect(source, contains('noRoads'));
    expect(source, contains('DisableWater'));
    expect(source, contains('noWater'));
    expect(source, contains('DisableWaterOutline'));
    expect(source, contains('noWaterOutline'));
    expect(source, contains('DisableWaterway'));
    expect(source, contains('noWaterway'));
    expect(source, contains('DisablePier'));
    expect(source, contains('noPier'));
    expect(source, contains('WhenDirtyRefresh'));
    expect(source, contains('whenDirtyRefresh'));
    expect(source, contains(r'[int]$MinimumFrameCount = 60'));
    expect(source, contains(r'native_surface_only = $true'));
    expect(source, contains(r'$totalFrames -ge $MinimumFrameCount'));
    expect(source, contains('minimum_frame_count'));
    expect(source, contains('totalFrames = Get-LayerIntMetric'));
    expect(source, contains('Native MapLibre proof label'));
    expect(source, contains('minimum frame count'));
    expect(activity, contains('MapLibre.getInstance(this)'));
    expect(activity, contains('mapView = MapView(this)'));
    expect(activity, contains('asset://fishergo_game_style.json'));
    expect(activity, contains('prefetchesTiles = false'));
    expect(activity, contains('prefetchZoomDelta = 0'));
    expect(activity, contains('noBuildingExtrusion'));
    expect(activity, contains('style.removeLayer("building-3d")'));
    expect(activity, contains('noLandcover'));
    expect(activity, contains('style.removeLayer("grass")'));
    expect(activity, contains('style.removeLayer("wood")'));
    expect(activity, contains('style.removeLayer("park")'));
    expect(activity, contains('noFillAntialias'));
    expect(activity, contains('PropertyFactory.fillAntialias(false)'));
    expect(activity, contains('noRoads'));
    expect(activity, contains('style.removeLayer("road-main")'));
    expect(activity, contains('noWater'));
    expect(activity, contains('style.removeLayer("water")'));
    expect(activity, contains('noWaterOutline'));
    expect(activity, contains('FillLayer'));
    expect(activity, contains('PropertyFactory.fillOutlineColor'));
    expect(activity, contains('noWaterway'));
    expect(activity, contains('style.removeLayer("waterway")'));
    expect(activity, contains('noPier'));
    expect(activity, contains('style.removeLayer("pier")'));
    expect(activity, contains('RenderingRefreshMode.WHEN_DIRTY'));
    expect(activity, contains('map.setStyle('));
    expect(activity, contains('tilt(45.0)'));
    expect(activity, contains('bearing(0.0)'));
  });
}
