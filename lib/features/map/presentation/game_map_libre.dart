import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:maplibre/maplibre.dart';

import '../../../core/config/public_app_config.dart';
import '../../../core/telemetry/app_telemetry.dart';
import '../application/map_performance_monitor.dart';
import '../application/map_cache_policy.dart';
import '../domain/map_bearing.dart';
import '../domain/game_map_spot.dart';
import 'game_map_marker_layer.dart';
import 'game_map_style.dart';
import 'native_fishing_spot_layer.dart';
import 'native_player_layer.dart';

/// MapLibre base map plus screen-space FisherGO gameplay markers.
///
/// The map owns geographic camera gestures. The game owns the marker widgets
/// and selection callbacks, so HUD state never rotates with the base map.
class GameMapLibre extends StatefulWidget {
  const GameMapLibre({
    super.key,
    required this.playerLocation,
    required this.playerMarker,
    this.playerMarkerKey = 'default',
    required this.spots,
    required this.onSpotSelected,
    this.selectedSpotId,
    this.hasLiveLocation = false,
    this.initialZoom = 16.0,
    this.initialPitch = 45.0,
    this.initialBearing = 0.0,
    this.showAttribution = true,
    this.onReady,
    this.onLoadTimeout,
    this.onMapCreated,
    this.onBearingChanged,
  });

  final Geographic playerLocation;
  final Widget playerMarker;
  final String playerMarkerKey;
  final List<GameMapSpot> spots;
  final ValueChanged<GameMapSpot> onSpotSelected;
  final String? selectedSpotId;
  final bool hasLiveLocation;
  final double initialZoom;
  final double initialPitch;
  final double initialBearing;
  final bool showAttribution;
  final VoidCallback? onReady;
  final VoidCallback? onLoadTimeout;
  final ValueChanged<MapController>? onMapCreated;
  final ValueChanged<double>? onBearingChanged;

  @override
  State<GameMapLibre> createState() => _GameMapLibreState();
}

class _GameMapLibreState extends State<GameMapLibre> {
  MapController? _mapController;
  MapPerformanceMonitor? _performanceMonitor;
  MapPerformanceReporter? _performanceReporter;
  TimingsCallback? _timingsCallback;
  int _performanceFrameCount = 0;
  bool _styleReady = false;
  bool _readinessLogged = false;
  bool _nativeFishingSpotIconReady = false;
  bool _nativePlayerIconReady = false;
  double? _lastReportedBearing;
  final ValueNotifier<bool> _mapInMotion = ValueNotifier<bool>(false);
  final Stopwatch _mapLoadClock = Stopwatch();
  StyleController? _styleController;
  Timer? _loadTimeoutTimer;

  static const mapLoadTimeout = Duration(seconds: 15);

  bool get _nativePlayerRequested =>
      !kIsWeb && PublicAppConfig.mapNativePlayerLayerEnabled;

  bool get _useNativePlayerLayer =>
      _nativePlayerRequested && _nativePlayerIconReady;

  bool get _useCompactStyle =>
      PublicAppConfig.mapCompactStyleEnabled ||
      (!kIsWeb && PublicAppConfig.mapAndroidCompactStyleEnabled);

  bool get _useGame3dStyle =>
      PublicAppConfig.mapGame3dStyleEnabled ||
      (!kIsWeb && PublicAppConfig.mapAndroidGame3dStyleEnabled);

  bool get _androidMarkerMotionOptimization =>
      defaultTargetPlatform == TargetPlatform.android &&
      PublicAppConfig.mapAndroidMarkerMotionOptimizationEnabled;

  @override
  void initState() {
    super.initState();
    _mapLoadClock.start();
    _loadTimeoutTimer = Timer(mapLoadTimeout, _onLoadTimeout);
    unawaited(MapCachePolicy.configureOnce());
    if (PublicAppConfig.mapOfflineWarmupEnabled && widget.hasLiveLocation) {
      MapCachePolicy.scheduleNearbyWarmup(center: widget.playerLocation);
    }
    if (!PublicAppConfig.mapPerformanceEnabled) return;

    _performanceMonitor = MapPerformanceMonitor()..markStarted();
    _performanceReporter = MapPerformanceReporter();
    _timingsCallback = (timings) {
      final monitor = _performanceMonitor;
      if (monitor == null) return;

      for (final timing in timings) {
        monitor.recordFrame(
          MapFrameSample(
            buildDuration: timing.buildDuration,
            rasterDuration: timing.rasterDuration,
            totalDuration: timing.totalSpan,
            vsyncOverhead: timing.vsyncOverhead,
            frameGap: frameTimingGap(timing),
          ),
        );
        _performanceFrameCount++;
      }

      if (_performanceReporter?.shouldReport(_performanceFrameCount) ?? false) {
        debugPrint('FisherGO map performance: ${monitor.snapshot().toJson()}');
      }
    };
    SchedulerBinding.instance.addTimingsCallback(_timingsCallback!);
  }

  @override
  void dispose() {
    _loadTimeoutTimer?.cancel();
    _mapLoadClock.stop();
    final timingsCallback = _timingsCallback;
    if (timingsCallback != null) {
      SchedulerBinding.instance.removeTimingsCallback(timingsCallback);
    }
    _mapInMotion.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant GameMapLibre oldWidget) {
    super.didUpdateWidget(oldWidget);
    final locationChanged =
        oldWidget.playerLocation.lat != widget.playerLocation.lat ||
            oldWidget.playerLocation.lon != widget.playerLocation.lon;
    if (locationChanged && _mapController != null) {
      unawaited(
        _moveMapLibreCenter(
          _mapController!,
          widget.playerLocation,
        ),
      );
    }
    if (locationChanged &&
        PublicAppConfig.mapOfflineWarmupEnabled &&
        widget.hasLiveLocation) {
      MapCachePolicy.scheduleNearbyWarmup(center: widget.playerLocation);
    }
    if (oldWidget.playerMarkerKey != widget.playerMarkerKey) {
      final style = _styleController;
      if (style != null && _nativePlayerRequested) {
        unawaited(_registerNativePlayerIcon(style));
      }
    }
  }

  Future<void> _moveMapLibreCenter(
    MapController controller,
    Geographic center,
  ) async {
    try {
      await controller.moveCamera(
        center: center,
      );
    } catch (_) {
      // The map may still be initializing when the first GPS fix arrives.
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseStyle = PublicAppConfig.mapLowPowerStyleEnabled
        ? fisherGoLowPowerMapStyle
        : kIsWeb && PublicAppConfig.mapWebMotionStyleEnabled
            ? fisherGoWebMotionMapStyle
            : _useGame3dStyle
                ? PublicAppConfig.mapFixedBuildingHeightEnabled
                    ? fisherGoFixedBuildingHeightGame3dMapStyle
                    : fisherGoGame3dMapStyle
                : _useCompactStyle
                    ? fisherGoCompactMapStyle
                    : fisherGoMapStyle;
    return MapLibreMap(
      options: MapOptions(
        initStyle: baseStyle,
        initCenter: widget.playerLocation,
        initZoom: widget.initialZoom,
        initPitch: widget.initialPitch,
        initBearing: widget.initialBearing,
        gestures: const MapGestures.all(),
        androidTextureMode: PublicAppConfig.mapTextureModeEnabled,
        androidMode: PublicAppConfig.mapVirtualDisplayEnabled
            ? AndroidPlatformViewMode.vd
            : PublicAppConfig.mapDirectHybridCompositionEnabled
                ? AndroidPlatformViewMode.hc
                : PublicAppConfig.mapHybridCompositionEnabled
                    ? AndroidPlatformViewMode.tlhc_hc
                    : AndroidPlatformViewMode.tlhc_vd,
      ),
      onMapCreated: (controller) {
        _mapController = controller;
        widget.onMapCreated?.call(controller);
      },
      onEvent: _onMapEvent,
      onStyleLoaded: _onStyleLoaded,
      layers: [
        if (PublicAppConfig.mapNativeFishingSpotLayerEnabled)
          ...buildNativeFishingSpotLayers(
            widget.spots,
            selectedSpotId: widget.selectedSpotId,
            includeLabels: kIsWeb,
            spotIconImageId: kIsWeb && _nativeFishingSpotIconReady
                ? nativeFishingSpotIconImageId
                : null,
          ),
        if (_useNativePlayerLayer)
          ...buildNativePlayerLayer(
            widget.playerLocation,
            imageId: nativePlayerImageId,
          ),
      ],
      children: [
        if (PublicAppConfig.mapFlutterMarkersEnabled)
          ValueListenableBuilder<bool>(
            valueListenable: _mapInMotion,
            builder: (context, mapInMotion, child) {
              return GameMapMarkerLayer(
                markers: _buildMarkers(
                  motionOptimized:
                      _androidMarkerMotionOptimization && mapInMotion,
                ),
              );
            },
          ),
        if (widget.showAttribution) const SourceAttribution(),
        const MapCompass(alignment: Alignment.topLeft),
      ],
    );
  }

  void _onStyleLoaded(StyleController style) {
    if (_styleReady) return;
    _styleReady = true;
    _loadTimeoutTimer?.cancel();
    _styleController = style;
    _performanceMonitor?.markStyleReady();
    final readinessFields = <String, Object?>{
      'native': !kIsWeb,
      'pitch': widget.initialPitch,
      'styleReadyMs': _mapLoadClock.elapsedMilliseconds,
    };
    final performanceSnapshot = _performanceMonitor?.snapshot();
    final instrumentedStyleReady = performanceSnapshot?.styleReadyAfter;
    if (instrumentedStyleReady != null) {
      readinessFields['instrumentedStyleReadyMs'] =
          instrumentedStyleReady.inMilliseconds;
    }
    unawaited(
      AppTelemetry.instance.record(
        TelemetryEventName.mapReady,
        fields: readinessFields,
      ),
    );
    if (_nativePlayerRequested) {
      unawaited(_registerNativePlayerIcon(style));
    }
    if (PublicAppConfig.mapNativeFishingSpotLayerEnabled && kIsWeb) {
      unawaited(_registerNativeFishingSpotIcon(style));
    }
    widget.onReady?.call();
  }

  void _onLoadTimeout() {
    if (_styleReady || !mounted) return;
    debugPrint(
      'FisherGO MapLibre style timeout after '
      '${mapLoadTimeout.inSeconds}s; requesting local fallback.',
    );
    unawaited(
      AppTelemetry.instance.record(
        TelemetryEventName.mapFallback,
        fields: {'timeoutSeconds': mapLoadTimeout.inSeconds},
      ),
    );
    widget.onLoadTimeout?.call();
  }

  Future<void> _registerNativePlayerIcon(StyleController style) async {
    try {
      if (_nativePlayerIconReady) {
        if (mounted) setState(() => _nativePlayerIconReady = false);
        await style.removeImage(nativePlayerImageId);
      }
      await style.addImageFromWidget(
        id: nativePlayerImageId,
        widget: widget.playerMarker,
        logicalSize: const Size(96, 116),
        imageSize: const Size(192, 232),
      );
      if (!mounted) return;
      setState(() => _nativePlayerIconReady = true);
      if (PublicAppConfig.mapPerformanceEnabled) {
        debugPrint('FisherGO native player icon registered');
      }
    } catch (error, stackTrace) {
      debugPrint(
        'FisherGO native player icon registration failed: $error\n$stackTrace',
      );
    }
  }

  Future<void> _registerNativeFishingSpotIcon(StyleController style) async {
    try {
      await style.addImageFromAssets(
        id: nativeFishingSpotIconImageId,
        asset: nativeFishingSpotIconAsset,
      );
      if (!mounted) return;
      setState(() => _nativeFishingSpotIconReady = true);
      if (PublicAppConfig.mapPerformanceEnabled) {
        debugPrint(
          'FisherGO native spot icon registered: '
          '$nativeFishingSpotIconImageId',
        );
      }
    } catch (error, stackTrace) {
      debugPrint(
        'FisherGO native spot icon registration failed: $error\n$stackTrace',
      );
    }
  }

  void _onMapEvent(MapEvent event) {
    if (event is MapEventMoveCamera) {
      final bearing = normalizeMapBearing(event.camera.bearing);
      final previous = _lastReportedBearing;
      final delta =
          previous == null ? double.infinity : (bearing - previous).abs();
      final shortestDelta = delta > 180 ? 360 - delta : delta;
      if (previous == null || shortestDelta >= 0.25) {
        _lastReportedBearing = bearing;
        widget.onBearingChanged?.call(bearing);
      }
    }
    if (event case MapEventClick()) {
      _selectNativeSpot(event);
      return;
    }
    if (event is MapEventStartMoveCamera) {
      _setMapInMotion(true);
      return;
    }
    if (event is! MapEventIdle && event is! MapEventCameraIdle) return;
    _setMapInMotion(false);
    if (_readinessLogged) return;

    final monitor = _performanceMonitor;
    monitor?.markMapIdle();
    _readinessLogged = true;
    final readinessFields = <String, Object?>{
      'mapIdleMs': _mapLoadClock.elapsedMilliseconds,
    };
    final performanceSnapshot = monitor?.snapshot();
    final instrumentedMapIdle = performanceSnapshot?.mapIdleAfter;
    if (performanceSnapshot != null && instrumentedMapIdle != null) {
      readinessFields['instrumentedMapIdleMs'] =
          instrumentedMapIdle.inMilliseconds;
      debugPrint('FisherGO map readiness: ${performanceSnapshot.toJson()}');
    }
    unawaited(
      AppTelemetry.instance.record(
        TelemetryEventName.mapIdle,
        fields: readinessFields,
      ),
    );
  }

  void _setMapInMotion(bool value) {
    if (!_androidMarkerMotionOptimization || _mapInMotion.value == value) {
      return;
    }
    if (!mounted) return;
    _mapInMotion.value = value;
  }

  void _selectNativeSpot(MapEventClick event) {
    if (!PublicAppConfig.mapNativeFishingSpotLayerEnabled) return;
    final controller = _mapController;
    if (controller == null) return;

    try {
      final queriedLayers = controller.queryLayers(event.screenPoint);
      final features = controller.featuresAtPoint(
        event.screenPoint,
        layerIds: nativeFishingSpotLayerIds,
      );
      if (PublicAppConfig.mapPerformanceEnabled) {
        debugPrint(
          'FisherGO native spot click: point=${event.screenPoint}, '
          'layers=$queriedLayers, features=${features.length}',
        );
      }
      final spot = resolveNativeFishingSpot(features, widget.spots);
      if (spot != null) widget.onSpotSelected(spot);
    } catch (error, stackTrace) {
      debugPrint('FisherGO native spot query failed: $error\n$stackTrace');
    }
  }

  List<GameMapMarker> _buildMarkers({bool motionOptimized = false}) {
    final markers = <GameMapMarker>[
      if (!_useNativePlayerLayer)
        // Keep the avatar behind a fishing spot so a nearby spot remains
        // tappable when the player is standing directly on its coordinate.
        GameMapMarker(
          point: widget.playerLocation,
          size: const Size(96, 116),
          alignment: const Alignment(0, 0.82),
          child: IgnorePointer(
            child: _PlayerMapMarker(
              marker: widget.playerMarker,
              hasLiveLocation: widget.hasLiveLocation,
            ),
          ),
        ),
      if (!PublicAppConfig.mapNativeFishingSpotLayerEnabled)
        for (final spot in widget.spots)
          GameMapMarker(
            point: spot.point,
            size: const Size(104, 92),
            alignment: const Alignment(0, 0.86),
            interactive: true,
            child: Semantics(
              button: true,
              label: '釣點 ${spot.displayLabel}',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => widget.onSpotSelected(spot),
                child: _MapFishingSpotMarker(
                  spot: spot,
                  selected: spot.id == widget.selectedSpotId,
                  motionOptimized: motionOptimized,
                ),
              ),
            ),
          ),
    ];
    return markers;
  }
}

class _MapFishingSpotMarker extends StatelessWidget {
  const _MapFishingSpotMarker({
    required this.spot,
    required this.selected,
    this.motionOptimized = false,
  });

  final GameMapSpot spot;
  final bool selected;
  final bool motionOptimized;

  @override
  Widget build(BuildContext context) {
    final color = spot.locked ? const Color(0xFF92A5AA) : spot.markerColor;
    // Android markers skip soft shadows because native map raster is already
    // the dominant motion cost; Web keeps the richer treatment.
    final isAndroid = defaultTargetPlatform == TargetPlatform.android &&
        !PublicAppConfig.mapAndroidMarkerShadowsEnabled;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: motionOptimized
              ? Duration.zero
              : const Duration(milliseconds: 180),
          width: selected ? 54 : 46,
          height: selected ? 54 : 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.22),
            border: Border.all(
              color: selected ? Colors.white : color,
              width: selected ? 3 : 2,
            ),
            boxShadow: [
              if (!isAndroid)
                BoxShadow(
                  color: color.withValues(alpha: selected ? 0.72 : 0.42),
                  blurRadius: selected ? 18 : 10,
                  spreadRadius: selected ? 3 : 0,
                ),
            ],
          ),
          child: Icon(
            spot.locked ? Icons.lock_outline : Icons.phishing,
            color: spot.locked ? Colors.white70 : Colors.white,
            size: selected ? 27 : 23,
          ),
        ),
        if (!motionOptimized && (selected || !spot.locked))
          Container(
            constraints: const BoxConstraints(maxWidth: 104),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xE60A2A32),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: color.withValues(alpha: 0.75)),
            ),
            child: Text(
              spot.displayLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

class _PlayerMapMarker extends StatelessWidget {
  const _PlayerMapMarker({required this.marker, required this.hasLiveLocation});

  final Widget marker;
  final bool hasLiveLocation;

  @override
  Widget build(BuildContext context) {
    final isAndroid = defaultTargetPlatform == TargetPlatform.android &&
        !PublicAppConfig.mapAndroidMarkerShadowsEnabled;
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 74,
          height: 74,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: hasLiveLocation ? const Color(0xFF70FFF0) : Colors.white70,
              width: 2,
            ),
            boxShadow: [
              if (!isAndroid)
                BoxShadow(
                  color: Color(0x6640EDE0),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
            ],
          ),
        ),
        SizedBox(width: 76, height: 104, child: marker),
      ],
    );
  }
}
