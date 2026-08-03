import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('GameHome starts at the nearby 500 metre gameplay scale', () {
    final source = File(
      'lib/features/game_home/presentation/game_home_screen.dart',
    ).readAsStringSync();

    expect(source, contains('const double gameMapInitialZoom = 16.0;'));
    expect(source, contains('LatLng(22.3520, 114.1016)'));
    expect(source,
        contains('static const double _spotDisplayRadiusMeters = 500;'));
    expect(source,
        contains('_distanceMeters(_playerLatLng, LatLng(spot.lat, spot.lng))'));
  });

  test('configured remote spots do not flash bundled points before loading',
      () {
    final source = File(
      'lib/features/game_home/presentation/game_home_screen.dart',
    ).readAsStringSync();

    expect(source, contains('SupabaseConfig.isConfigured'));
    expect(source,
        contains('List<_SpotDemo> _nearbySpots = SupabaseConfig.isConfigured'));
    expect(source, contains('_isFishingSpotRegistryLoading = false'));
    expect(source, contains('500 米內暫無已核實釣點'));
    expect(source, contains('onOpenPanorama: _openPanoramaMap'));
  });

  test('GameHome rejects unaudited or malformed spots at the game boundary',
      () {
    final source = File(
      'lib/features/game_home/presentation/game_home_screen.dart',
    ).readAsStringSync();

    expect(source, contains('if (!spot.isPubliclyEligible)'));
    expect(source, contains('audited verified spots'));
  });

  test(
      'HUD composition diagnostic is opt-in and leaves the map surface mounted',
      () {
    final source = File(
      'lib/features/game_home/presentation/game_home_screen.dart',
    ).readAsStringSync();
    final config = File(
      'lib/core/config/public_app_config.dart',
    ).readAsStringSync();

    expect(config, contains('mapHudCompositionDiagnosticEnabled'));
    expect(config, contains('FISHERGO_MAP_HUD_COMPOSITION_DIAGNOSTIC'));
    expect(config, contains('mapHudDiagnosticProfile'));
    expect(config, contains('FISHERGO_MAP_HUD_PROFILE'));
    expect(source, contains('_mapSurfaceWidget,'));
    expect(
        source,
        contains(
            'offstage: PublicAppConfig.mapHudCompositionDiagnosticEnabled'));
    expect(source, contains('mapHudNavigationHidden'));
    expect(source, contains('mapHudUtilityHidden'));
    expect(source, contains('mapHudBottomHidden'));
    expect(config, contains('mapHudWidgetHidden'));
    expect(source, contains("mapHudWidgetHidden('top-status')"));
    expect(source, contains("mapHudWidgetHidden('panorama')"));
    expect(source, contains("mapHudWidgetHidden('rotate')"));
    expect(source, contains("mapHudWidgetHidden('side')"));
    expect(source, contains("mapHudWidgetHidden('locate')"));
    expect(source, contains("mapHudWidgetHidden('announcement')"));
    expect(source, contains("mapHudWidgetHidden('bottom-bar')"));
    expect(source, contains("mapHudWidgetHidden('spot-detail')"));
    expect(source, contains("mapHudWidgetHidden('fishing-overlay')"));
  });

  test('MapLibre load timeout keeps a local geometry fallback available', () {
    final source = File(
      'lib/features/game_home/presentation/game_home_screen.dart',
    ).readAsStringSync();

    expect(source, contains('_isMapLibreMapActive'));
    expect(source, contains('_useVectorFallbackForMap'));
    expect(source, contains('onMapLibreLoadTimeout'));
    expect(source, contains('useVectorFallback'));
    expect(source, contains('_loadTerrainDataset()'));
    expect(source, contains('VectorFallbackSurface'));
  });

  test('panorama map shares the production MapLibre surface', () {
    final source = File(
      'lib/features/game_home/presentation/game_home_screen.dart',
    ).readAsStringSync();
    final panoramaStart = source.indexOf('class _PanoramaMapSheet');

    expect(panoramaStart, greaterThanOrEqualTo(0));
    final panoramaSource = source.substring(panoramaStart);
    expect(panoramaSource, contains('GameMapLibre('));
    expect(panoramaSource, contains('initialPitch: 0'));
    expect(panoramaSource, contains('initialZoom: 13'));
    expect(panoramaSource, isNot(contains('FlutterMap(')));
    expect(panoramaSource, isNot(contains('TileLayer(')));
  });
}
