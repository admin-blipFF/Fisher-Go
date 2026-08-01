import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:maplibre/maplibre.dart';

/// Keeps MapLibre's persistent Android tile cache useful without allowing a
/// long-running gameplay session to grow it without bounds.
class MapCachePolicy {
  static const offlineTileLimit = 4000;
  static const ambientCacheBytes = 64 * 1024 * 1024;
  static const packDatabaseAutomatically = true;
  static const warmupRadiusMeters = 500.0;
  static const warmupMinZoom = 14.0;
  static const warmupMaxZoom = 16.0;
  static const warmupPixelDensity = 1.0;
  static const warmupStyleUrl = 'https://tiles.openfreemap.org/styles/liberty';
  static const warmupDebounce = Duration(seconds: 2);
  static const warmupGridDegrees = 0.002;

  static Future<void>? _configuration;
  static Timer? _warmupTimer;
  static Future<void>? _warmupInFlight;
  static Geographic? _queuedCenter;
  static String? _lastWarmupKey;
  static int? _previousRegionId;

  const MapCachePolicy._();

  /// Configures the Android native cache once. Web and iOS keep their
  /// platform-default cache path until they have their own benchmark.
  static Future<void> configureOnce() {
    return _configuration ??= _configure();
  }

  static Future<void> _configure() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    if (!OfflineManager.isSupported) return;

    OfflineManager? manager;
    try {
      manager = await OfflineManager.createInstance();
      manager.setOfflineTileCountLimit(amount: offlineTileLimit);
      manager.runPackDatabaseAutomatically(
        enabled: packDatabaseAutomatically,
      );
      await manager.setMaximumAmbientCacheSize(bytes: ambientCacheBytes);
    } catch (error, stackTrace) {
      debugPrint('FisherGO map cache policy unavailable: $error\n$stackTrace');
    } finally {
      manager?.dispose();
    }
  }

  /// Schedules a small GPS-centred region download without holding up map
  /// creation. Nearby movement is debounced and quantized to avoid creating a
  /// new offline region for every location callback.
  static void scheduleNearbyWarmup({required Geographic center}) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

    _queuedCenter = center;
    _warmupTimer?.cancel();
    _warmupTimer = Timer(warmupDebounce, () {
      final nextCenter = _queuedCenter;
      _queuedCenter = null;
      if (nextCenter != null) unawaited(warmNearbyRegion(nextCenter));
    });
  }

  /// Downloads the current 500m gameplay area into MapLibre's offline cache.
  /// The Liberty style is only a cache manifest; FisherGO continues rendering
  /// its own inline Game 3D style, which points at the same OpenMapTiles data.
  static Future<void> warmNearbyRegion(Geographic center) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

    final key = warmupGridKey(center);
    if (_lastWarmupKey == key) return;
    if (_warmupInFlight != null) {
      _queuedCenter = center;
      return;
    }

    final task = _downloadNearbyRegion(center, key);
    _warmupInFlight = task;
    try {
      await task;
    } finally {
      _warmupInFlight = null;
      final queuedCenter = _queuedCenter;
      _queuedCenter = null;
      if (queuedCenter != null &&
          warmupGridKey(queuedCenter) != _lastWarmupKey) {
        scheduleNearbyWarmup(center: queuedCenter);
      }
    }
  }

  static LngLatBounds warmupBoundsFor(Geographic center) {
    const metersPerDegree = 111320.0;
    final latitudeDelta = warmupRadiusMeters / metersPerDegree;
    final longitudeScale = math.cos(center.lat * math.pi / 180).abs();
    final longitudeDelta =
        warmupRadiusMeters / (metersPerDegree * math.max(longitudeScale, 0.01));

    return LngLatBounds(
      longitudeWest: center.lon - longitudeDelta,
      longitudeEast: center.lon + longitudeDelta,
      latitudeSouth: math.max(-90, center.lat - latitudeDelta),
      latitudeNorth: math.min(90, center.lat + latitudeDelta),
    );
  }

  static String warmupGridKey(Geographic center) {
    final latitudeBucket = (center.lat / warmupGridDegrees).round();
    final longitudeBucket = (center.lon / warmupGridDegrees).round();
    return '$latitudeBucket:$longitudeBucket';
  }

  static Future<void> _downloadNearbyRegion(
    Geographic center,
    String key,
  ) async {
    OfflineManager? manager;
    try {
      manager = await OfflineManager.createInstance();
      manager.setOfflineTileCountLimit(amount: offlineTileLimit);
      manager.runPackDatabaseAutomatically(
        enabled: packDatabaseAutomatically,
      );

      final existingWarmupRegions = await _listWarmupRegions(manager);
      final cachedRegion =
          existingWarmupRegions.cast<OfflineRegion?>().firstWhere(
                (region) => region?.metadata['grid'] == key,
                orElse: () => null,
              );
      if (cachedRegion != null) {
        _previousRegionId = cachedRegion.id;
        _lastWarmupKey = key;
        debugPrint(
          'FisherGO map cache warm-up hit: '
          'grid=$key region=${cachedRegion.id}',
        );
        return;
      }

      for (final staleRegion in existingWarmupRegions) {
        try {
          await manager.deleteRegion(regionId: staleRegion.id);
        } catch (error) {
          debugPrint(
            'FisherGO stale map warm-up cleanup skipped: '
            'region=${staleRegion.id} error=$error',
          );
        }
      }
      _previousRegionId = null;

      OfflineRegion? completedRegion;
      DownloadProgress? completedProgress;
      await for (final progress in manager.downloadRegion(
        mapStyleUrl: warmupStyleUrl,
        bounds: warmupBoundsFor(center),
        minZoom: warmupMinZoom,
        maxZoom: warmupMaxZoom,
        pixelDensity: warmupPixelDensity,
        metadata: <String, Object?>{
          'owner': 'fishergo',
          'purpose': 'gps-centered-500m-cache-warmup',
          'grid': key,
        },
      )) {
        if (progress.downloadCompleted) {
          completedRegion = progress.region;
          completedProgress = progress;
        }
      }

      final region = completedRegion;
      if (region == null) return;

      final previousRegionId = _previousRegionId;
      _previousRegionId = region.id;
      _lastWarmupKey = key;
      if (previousRegionId != null && previousRegionId != region.id) {
        try {
          await manager.deleteRegion(regionId: previousRegionId);
        } catch (error) {
          debugPrint('FisherGO previous map warm-up cleanup skipped: $error');
        }
      }
      debugPrint(
        'FisherGO map cache warm-up complete: '
        'grid=$key region=${region.id} '
        'tiles=${completedProgress?.loadedTiles} '
        'bytes=${completedProgress?.loadedBytes} '
        'bounds=${warmupBoundsFor(center)}',
      );
    } catch (error, stackTrace) {
      debugPrint('FisherGO map cache warm-up unavailable: $error\n$stackTrace');
    } finally {
      manager?.dispose();
    }
  }

  static Future<List<OfflineRegion>> _listWarmupRegions(
    OfflineManager manager,
  ) async {
    try {
      final regions = await manager.listOfflineRegions();
      return regions.where(_isWarmupRegion).toList(growable: false);
    } catch (error) {
      debugPrint('FisherGO map warm-up region listing skipped: $error');
      return const <OfflineRegion>[];
    }
  }

  static bool _isWarmupRegion(OfflineRegion region) =>
      region.metadata['owner'] == 'fishergo' &&
      region.metadata['purpose'] == 'gps-centered-500m-cache-warmup';
}
