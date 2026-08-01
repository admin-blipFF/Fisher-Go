import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

import 'features/map/application/map_performance_monitor.dart';
import 'features/game_home/domain/game_map_camera.dart';
import 'features/game_home/domain/game_map_feature_store.dart';
import 'features/game_home/domain/terrain_data_source.dart';
import 'features/map/presentation/vector_map_fallback.dart';

const _defaultCenter = LatLng(22.3855, 114.1915);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: VectorMapFallbackProofScreen(),
  ));
}

class VectorMapFallbackProofScreen extends StatefulWidget {
  const VectorMapFallbackProofScreen({super.key});

  @override
  State<VectorMapFallbackProofScreen> createState() =>
      _VectorMapFallbackProofScreenState();
}

class _VectorMapFallbackProofScreenState
    extends State<VectorMapFallbackProofScreen> {
  GeoTerrainDataSource? _terrainDataSource;
  double _bearingDegrees = 0;
  late final MapPerformanceMonitor _performanceMonitor;
  late final MapPerformanceReporter _performanceReporter;
  TimingsCallback? _timingsCallback;
  int _performanceFrameCount = 0;

  @override
  void initState() {
    super.initState();
    _performanceMonitor = MapPerformanceMonitor()..markStarted();
    _performanceReporter = MapPerformanceReporter();
    _timingsCallback = (timings) {
      for (final timing in timings) {
        _performanceMonitor.recordFrame(
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
      if (_performanceReporter.shouldReport(_performanceFrameCount)) {
        debugPrint(
          'FisherGO fallback performance: '
          '${_performanceMonitor.snapshot().toJson()}',
        );
      }
    };
    SchedulerBinding.instance.addTimingsCallback(_timingsCallback!);
    _loadTerrain();
  }

  @override
  void dispose() {
    final timingsCallback = _timingsCallback;
    if (timingsCallback != null) {
      SchedulerBinding.instance.removeTimingsCallback(timingsCallback);
    }
    super.dispose();
  }

  Future<void> _loadTerrain() async {
    final source =
        await rootBundle.loadString('assets/maps/hk_terrain_mvp.json');
    final dataset = await compute(GeoTerrainDataset.fromJson, source);
    if (!mounted) return;
    setState(() => _terrainDataSource = GeoTerrainDataSource(dataset));
  }

  @override
  Widget build(BuildContext context) {
    final terrainDataSource = _terrainDataSource;
    return Scaffold(
      appBar: AppBar(title: const Text('Vector map fallback proof')),
      body: terrainDataSource == null
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) => _buildMap(
                context,
                terrainDataSource,
                Size(constraints.maxWidth, constraints.maxHeight),
              ),
            ),
    );
  }

  Widget _buildMap(
    BuildContext context,
    GeoTerrainDataSource terrainDataSource,
    Size viewportSize,
  ) {
    final featureStore =
        GameMapFeatureStore(dataset: terrainDataSource.dataset);
    final camera = GameMapCamera(
      center: _defaultCenter,
      visibleRadiusMeters: 500,
      bearingDegrees: _bearingDegrees,
      viewportSize: viewportSize,
      perspectiveStrength: 0.52,
      viewportAnchorY: 0.56,
    );
    final terrainFeatures = featureStore.visibleTerrainFeatures(camera);
    final fishingSpots = featureStore.projectFishingSpots(
      camera: camera,
      spots: const [
        GameMapFishingSpot(
          id: 'spot-shatin',
          name: '沙田測試釣點',
          position: LatLng(22.3855, 114.1915),
        ),
        GameMapFishingSpot(
          id: 'spot-hilton',
          name: '希爾頓中心',
          position: LatLng(22.3812, 114.1874),
        ),
      ],
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: (details) {
        setState(() {
          _bearingDegrees = (_bearingDegrees + details.delta.dx * 0.45) % 360;
          if (_bearingDegrees < 0) _bearingDegrees += 360;
        });
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          const RepaintBoundary(
            child: CustomPaint(
              painter: VectorFallbackBackgroundPainter(),
            ),
          ),
          CustomPaint(
            painter: OptimizedVectorMapPainter(
              camera: camera,
              terrainFeatures: terrainFeatures,
              fishingSpots: fishingSpots,
            ),
          ),
          const Align(
            alignment: Alignment(0, 0.12),
            child: IgnorePointer(
              child: CircleAvatar(
                radius: 31,
                backgroundColor: Color(0xFFF7FFFF),
                child: Icon(Icons.person, color: Color(0xFF087F8C), size: 34),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            top: 16,
            child: Card(
              color: Colors.white.withValues(alpha: 0.92),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Text(
                  'GPS vector fallback · 500m · ${_bearingDegrees.round()}°\n'
                  'OSM roads / buildings / hydro · ${fishingSpots.length} spots',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.small(
              heroTag: 'reset-bearing',
              onPressed: () => setState(() => _bearingDegrees = 0),
              child: const Icon(Icons.explore),
            ),
          ),
        ],
      ),
    );
  }
}
