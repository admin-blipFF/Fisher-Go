import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('map performance telemetry is opt-in and detached from renderer choice',
      () {
    final config =
        File('lib/core/config/public_app_config.dart').readAsStringSync();
    final mapSurface = File('lib/features/map/presentation/game_map_libre.dart')
        .readAsStringSync();
    final classicRenderer = File(
      'lib/features/game_home/presentation/game_map_renderer.dart',
    ).readAsStringSync();
    final gameHome = File(
      'lib/features/game_home/presentation/game_home_screen.dart',
    ).readAsStringSync();
    final monitor = File(
      'lib/features/map/application/map_performance_monitor.dart',
    ).readAsStringSync();

    expect(config, contains('mapPerformanceEnabled'));
    expect(config, contains('FISHERGO_MAP_PERF'));
    expect(
        mapSurface, contains('SchedulerBinding.instance.addTimingsCallback'));
    expect(mapSurface, contains('removeTimingsCallback'));
    expect(mapSurface, contains('MapPerformanceMonitor'));
    expect(monitor, contains('p95TotalFrame'));
    expect(monitor, contains('styleReadyAfter'));
    expect(monitor, contains('mapIdleAfter'));
    expect(mapSurface, contains('MapEventIdle'));
    expect(mapSurface, contains('MapEventCameraIdle'));
    expect(mapSurface, contains('FisherGO map readiness:'));
    expect(classicRenderer, contains('class GameMapPerformanceProbe'));
    expect(classicRenderer,
        contains('SchedulerBinding.instance.addTimingsCallback'));
    expect(classicRenderer,
        contains('FisherGO map performance: renderer=classic'));
    expect(gameHome, contains('GameMapPerformanceProbe'));
  });
}
