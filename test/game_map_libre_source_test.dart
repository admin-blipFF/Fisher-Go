import 'dart:io';

import 'package:fishergo/features/map/domain/map_bearing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('MapLibre game surface is wired behind an explicit feature flag', () {
    final publicConfig = File('lib/core/config/public_app_config.dart');
    final gameHome =
        File('lib/features/game_home/presentation/game_home_screen.dart');
    final mapSurface =
        File('lib/features/map/presentation/game_map_libre.dart');
    final markerLayer =
        File('lib/features/map/presentation/game_map_marker_layer.dart');

    expect(publicConfig.existsSync(), isTrue);
    expect(gameHome.existsSync(), isTrue);
    expect(mapSurface.existsSync(), isTrue);
    expect(markerLayer.existsSync(), isTrue);
    expect(publicConfig.readAsStringSync(), contains('mapLibreEnabled'));
    expect(
      publicConfig.readAsStringSync(),
      contains('mapTextureModeEnabled'),
    );
    expect(
      publicConfig.readAsStringSync(),
      contains('FISHERGO_MAP_TEXTURE'),
    );
    expect(
      publicConfig.readAsStringSync(),
      contains('mapHybridCompositionEnabled'),
    );
    expect(
      publicConfig.readAsStringSync(),
      contains('mapDirectHybridCompositionEnabled'),
    );
    expect(
      publicConfig.readAsStringSync(),
      contains('FISHERGO_MAP_HC_DIRECT'),
    );
    expect(
      publicConfig.readAsStringSync(),
      contains('mapCompactStyleEnabled'),
    );
    expect(
      publicConfig.readAsStringSync(),
      contains('mapAndroidCompactStyleEnabled'),
    );
    expect(
      publicConfig.readAsStringSync(),
      contains('FISHERGO_MAP_ANDROID_COMPACT'),
    );
    expect(
      publicConfig.readAsStringSync(),
      contains('mapLowPowerStyleEnabled'),
    );
    expect(
      publicConfig.readAsStringSync(),
      contains('mapWebMotionStyleEnabled'),
    );
    expect(
      publicConfig.readAsStringSync(),
      contains('FISHERGO_MAP_WEB_MOTION'),
    );
    expect(
      publicConfig.readAsStringSync(),
      contains('mapGame3dStyleEnabled'),
    );
    expect(
      publicConfig.readAsStringSync(),
      contains('FISHERGO_MAP_3D_STYLE'),
    );
    expect(
      publicConfig.readAsStringSync(),
      contains('mapAndroidGame3dStyleEnabled'),
    );
    expect(
      publicConfig.readAsStringSync(),
      contains('FISHERGO_MAP_ANDROID_3D_STYLE'),
    );
    expect(
      publicConfig.readAsStringSync(),
      contains('mapFlutterMarkersEnabled'),
    );
    expect(
      publicConfig.readAsStringSync(),
      contains('mapAndroidMarkerShadowsEnabled'),
    );
    expect(
      publicConfig.readAsStringSync(),
      contains('mapAndroidMarkerMotionOptimizationEnabled'),
    );
    expect(
      publicConfig.readAsStringSync(),
      contains('FISHERGO_MAP_ANDROID_MARKER_MOTION'),
    );
    expect(
      publicConfig.readAsStringSync(),
      contains('mapNativeFishingSpotLayerEnabled'),
    );
    expect(
      publicConfig.readAsStringSync(),
      contains('mapNativePlayerLayerEnabled'),
    );
    expect(
      publicConfig.readAsStringSync(),
      contains('mapMarkerProjectionDebugEnabled'),
    );
    expect(
      publicConfig.readAsStringSync(),
      contains('FISHERGO_MAP_NATIVE_SPOT_LAYER'),
    );
    expect(
      publicConfig.readAsStringSync(),
      contains('FISHERGO_MAP_ANDROID_MARKER_SHADOWS'),
    );
    expect(
      publicConfig.readAsStringSync(),
      contains('mapOfflineWarmupEnabled'),
    );
    expect(
      publicConfig.readAsStringSync(),
      contains('FISHERGO_MAP_CACHE_WARMUP'),
    );
    expect(
      publicConfig.readAsStringSync(),
      contains('defaultValue: false'),
    );
    expect(gameHome.readAsStringSync(),
        contains('PublicAppConfig.mapLibreEnabled'));
    expect(
      gameHome.readAsStringSync(),
      contains('if (!PublicAppConfig.mapLibreEnabled)'),
    );
    expect(
      gameHome.readAsStringSync(),
      contains('unawaited(_loadTerrainDataset())'),
    );
    expect(gameHome.readAsStringSync(), contains('GameMapLibre'));
    expect(gameHome.readAsStringSync(), contains('gameMapInitialZoom'));
    expect(mapSurface.readAsStringSync(), contains('GameMapMarkerLayer'));
    expect(mapSurface.readAsStringSync(), contains('_mapLoadClock'));
    expect(mapSurface.readAsStringSync(), contains('styleReadyMs'));
    expect(mapSurface.readAsStringSync(), contains('mapIdleMs'));
    expect(mapSurface.readAsStringSync(),
        contains('MapCachePolicy.configureOnce'));
    expect(mapSurface.readAsStringSync(),
        contains('MapCachePolicy.scheduleNearbyWarmup'));
    expect(mapSurface.readAsStringSync(),
        contains('PublicAppConfig.mapOfflineWarmupEnabled'));
    expect(mapSurface.readAsStringSync(), contains('widget.hasLiveLocation'));
    expect(mapSurface.readAsStringSync(), contains('MapGestures.all'));
    expect(mapSurface.readAsStringSync(), contains('initialBearing'));
    expect(
      mapSurface.readAsStringSync(),
      contains('initBearing: widget.initialBearing'),
    );
    expect(mapSurface.readAsStringSync(), contains('onEvent: _onMapEvent'));
    expect(
      mapSurface.readAsStringSync(),
      contains('MapEventStartMoveCamera'),
    );
    expect(mapSurface.readAsStringSync(), contains('MapEventMoveCamera'));
    expect(mapSurface.readAsStringSync(), contains('event.camera.bearing'));
    expect(mapSurface.readAsStringSync(), contains('onBearingChanged'));
    expect(mapSurface.readAsStringSync(), contains('_lastReportedBearing'));
    expect(mapSurface.readAsStringSync(), contains('shortestDelta >= 0.25'));
    expect(mapSurface.readAsStringSync(), contains('_setMapInMotion'));
    expect(mapSurface.readAsStringSync(), contains('motionOptimized'));
    expect(
      mapSurface.readAsStringSync(),
      contains('ValueNotifier<bool> _mapInMotion'),
    );
    expect(
      mapSurface.readAsStringSync(),
      contains('ValueListenableBuilder<bool>'),
    );
    expect(mapSurface.readAsStringSync(), contains('_mapInMotion.dispose()'));
    expect(
      markerLayer.readAsStringSync(),
      contains('class _GameMapMarkerLayerState'),
    );
    expect(markerLayer.readAsStringSync(), contains('_projectedPoints'));
    expect(markerLayer.readAsStringSync(), contains('didUpdateWidget'));
    expect(mapSurface.readAsStringSync(), contains('Timer? _loadTimeoutTimer'));
    expect(mapSurface.readAsStringSync(), contains('mapLoadTimeout'));
    expect(mapSurface.readAsStringSync(), contains('onLoadTimeout'));
    expect(mapSurface.readAsStringSync(),
        contains('widget.onLoadTimeout?.call()'));
    expect(
        mapSurface.readAsStringSync(), contains('_loadTimeoutTimer?.cancel()'));
    expect(
      mapSurface.readAsStringSync(),
      contains('androidTextureMode: PublicAppConfig.mapTextureModeEnabled'),
    );
    final mapSurfaceContents = mapSurface.readAsStringSync();
    expect(
      mapSurface.readAsStringSync(),
      contains('PublicAppConfig.mapHybridCompositionEnabled'),
    );
    expect(
      mapSurface.readAsStringSync(),
      contains('PublicAppConfig.mapDirectHybridCompositionEnabled'),
    );
    expect(
      mapSurface.readAsStringSync(),
      contains('PublicAppConfig.mapVirtualDisplayEnabled'),
    );
    expect(
      mapSurface.readAsStringSync(),
      contains('fisherGoCompactMapStyle'),
    );
    expect(
      mapSurface.readAsStringSync(),
      contains('mapAndroidCompactStyleEnabled'),
    );
    expect(
      mapSurface.readAsStringSync(),
      contains('fisherGoLowPowerMapStyle'),
    );
    expect(
      mapSurface.readAsStringSync(),
      contains('fisherGoWebMotionMapStyle'),
    );
    expect(
      mapSurface.readAsStringSync(),
      contains('fisherGoGame3dMapStyle'),
    );
    expect(
      mapSurface.readAsStringSync(),
      contains('mapFlutterMarkersEnabled'),
    );
    expect(
      mapSurface.readAsStringSync(),
      contains('AndroidPlatformViewMode.tlhc_hc'),
    );
    expect(
      mapSurface.readAsStringSync(),
      contains('AndroidPlatformViewMode.tlhc_vd'),
    );
    expect(
      mapSurface.readAsStringSync(),
      contains('AndroidPlatformViewMode.hc'),
    );
    expect(
      mapSurface.readAsStringSync(),
      contains('AndroidPlatformViewMode.vd'),
    );
    expect(
      mapSurface.readAsStringSync(),
      contains('alignment: Alignment.topLeft'),
    );

    final markerContents = markerLayer.readAsStringSync();
    expect(markerContents, contains('MapController.maybeOf'));
    expect(markerContents, contains('MapCamera.maybeOf'));
    expect(markerContents, contains('camera == null'));
    expect(markerContents, contains('PointerInterceptor'));
    expect(markerContents, contains('RepaintBoundary'));
    expect(
      markerContents,
      contains('PublicAppConfig.mapMarkerProjectionDebugEnabled'),
    );

    expect(mapSurfaceContents, contains('defaultTargetPlatform'));
    expect(mapSurfaceContents, contains('TargetPlatform.android'));
    expect(mapSurfaceContents, contains('Android markers skip soft shadows'));
    expect(mapSurfaceContents, contains('buildNativeFishingSpotLayers'));
    expect(
        mapSurfaceContents, contains('kIsWeb && _nativeFishingSpotIconReady'));
    expect(mapSurfaceContents, contains('addImageFromAssets'));
    expect(mapSurfaceContents, contains('nativeFishingSpotIconImageId'));
    expect(mapSurfaceContents, contains('nativeFishingSpotIconAsset'));
    expect(mapSurfaceContents, contains('featuresAtPoint'));
    expect(mapSurfaceContents, contains('nativeFishingSpotLayerIds'));
    expect(mapSurfaceContents, contains('buildNativePlayerLayer'));
    expect(mapSurfaceContents, contains('addImageFromWidget'));
    expect(mapSurfaceContents, contains('nativePlayerImageId'));
    expect(markerContents, contains('FisherGO marker projections'));
    expect(mapSurfaceContents, contains('_moveMapLibreCenter'));
    expect(
      mapSurfaceContents,
      contains(
          'The map may still be initializing when the first GPS fix arrives.'),
    );
  });

  test('MapLibre bearing normalization keeps the HUD range stable', () {
    expect(normalizeMapBearing(0), 0);
    expect(normalizeMapBearing(360), 0);
    expect(normalizeMapBearing(-45), 315);
    expect(normalizeMapBearing(725), 5);
  });
}
