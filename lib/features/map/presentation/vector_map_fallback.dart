import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../game_home/domain/game_map_camera.dart';
import '../../game_home/domain/game_map_feature_store.dart';
import '../../game_home/domain/game_road_style.dart';
import '../../game_home/presentation/game_map_renderer.dart';
import '../../game_home/domain/terrain_data_source.dart';
import '../application/map_performance_monitor.dart';

class VectorFallbackBackgroundPainter extends CustomPainter {
  const VectorFallbackBackgroundPainter({
    this.camera,
    this.texturePack = const GameMapTexturePack(),
    this.texturesEnabled = true,
  });

  final GameMapCamera? camera;
  final GameMapTexturePack texturePack;
  final bool texturesEnabled;

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    final bounds = ui.Offset.zero & size;
    canvas.drawRect(
      bounds,
      ui.Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            ui.Color(0xFF8BD8B3),
            ui.Color(0xFF58B87E),
            ui.Color(0xFF2D8562),
          ],
        ).createShader(bounds),
    );
    final grassImage =
        texturesEnabled ? texturePack.grassMicro ?? texturePack.land : null;
    if (grassImage != null) {
      canvas.drawRect(
        bounds,
        ui.Paint()
          ..shader = ui.ImageShader(
            grassImage,
            ui.TileMode.repeated,
            ui.TileMode.repeated,
            _worldTextureTransform(grassImage),
          )
          ..colorFilter = const ui.ColorFilter.mode(
            ui.Color(0x4DFFFFFF),
            ui.BlendMode.modulate,
          ),
      );
    }
    final grassPaint = ui.Paint()
      ..color = const ui.Color(0xFFB9F08B).withValues(alpha: 0.13)
      ..strokeWidth = 1.0;
    for (var y = -18.0; y < bounds.bottom + 28; y += 22) {
      canvas.drawLine(
        ui.Offset(0, y),
        ui.Offset(bounds.right, y + bounds.width * 0.08),
        grassPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant VectorFallbackBackgroundPainter oldDelegate) {
    if (oldDelegate.texturePack != texturePack ||
        oldDelegate.texturesEnabled != texturesEnabled) {
      return true;
    }
    // During camera motion this layer is a fixed-color cache, so bearing
    // changes must not invalidate its rasterized background.
    if (!texturesEnabled) return false;
    return oldDelegate.camera != camera;
  }

  Float64List _worldTextureTransform(ui.Image image) {
    final currentCamera = camera;
    if (currentCamera == null) {
      return Matrix4.identity().storage;
    }
    return terrainWorldShaderTransform(
      imageSize: Size(image.width.toDouble(), image.height.toDouble()),
      camera: currentCamera,
      tileWorldMeters: 300,
    ).storage;
  }
}

class VectorFallbackSurface extends StatefulWidget {
  const VectorFallbackSurface({
    required this.camera,
    required this.terrainFeatures,
    required this.fishingSpots,
    this.texturesEnabled = true,
    super.key,
  });

  final GameMapCamera camera;
  final List<TerrainVectorFeature> terrainFeatures;
  final List<ProjectedFishingSpot> fishingSpots;
  final bool texturesEnabled;

  @override
  State<VectorFallbackSurface> createState() => _VectorFallbackSurfaceState();
}

class _VectorFallbackSurfaceState extends State<VectorFallbackSurface> {
  static const _waterTexture = 'assets/maps/textures/water_tile_v2.jpg';
  static const _grassTexture = 'assets/maps/textures/grass_micro_tile.jpg';

  GameMapTexturePack _texturePack = const GameMapTexturePack();

  @override
  void initState() {
    super.initState();
    _loadTextures();
  }

  Future<void> _loadTextures() async {
    try {
      final images = await Future.wait<ui.Image>([
        _loadTexture(_waterTexture),
        _loadTexture(_grassTexture),
      ]);
      if (!mounted) return;
      setState(
        () => _texturePack = GameMapTexturePack(
          water: images[0],
          grassMicro: images[1],
        ),
      );
    } catch (_) {
      // The solid-color fallback remains usable if a texture cannot load.
    }
  }

  Future<ui.Image> _loadTexture(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    final bytes = Uint8List.view(
      data.buffer,
      data.offsetInBytes,
      data.lengthInBytes,
    );
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: VectorFallbackBackgroundPainter(
              camera: widget.camera,
              texturePack: _texturePack,
              texturesEnabled: widget.texturesEnabled,
            ),
          ),
          IgnorePointer(
            child: CustomPaint(
              painter: OptimizedVectorMapPainter(
                camera: widget.camera,
                terrainFeatures: widget.terrainFeatures,
                fishingSpots: widget.fishingSpots,
                texturePack: _texturePack,
                texturesEnabled: widget.texturesEnabled,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class VectorFallbackPerformanceProbe extends StatefulWidget {
  const VectorFallbackPerformanceProbe({required this.child, super.key});

  final Widget child;

  @override
  State<VectorFallbackPerformanceProbe> createState() =>
      _VectorFallbackPerformanceProbeState();
}

class _VectorFallbackPerformanceProbeState
    extends State<VectorFallbackPerformanceProbe> {
  late final MapPerformanceMonitor _monitor;
  late final MapPerformanceReporter _reporter;
  TimingsCallback? _timingsCallback;
  int _frameCount = 0;

  @override
  void initState() {
    super.initState();
    _monitor = MapPerformanceMonitor()..markStarted();
    _reporter = MapPerformanceReporter();
    _timingsCallback = (timings) {
      for (final timing in timings) {
        _monitor.recordFrame(
          MapFrameSample(
            buildDuration: timing.buildDuration,
            rasterDuration: timing.rasterDuration,
            totalDuration: timing.totalSpan,
            vsyncOverhead: timing.vsyncOverhead,
            frameGap: frameTimingGap(timing),
          ),
        );
        _frameCount++;
      }
      if (_reporter.shouldReport(_frameCount)) {
        debugPrint(
          'FisherGO fallback performance: ${_monitor.snapshot().toJson()}',
        );
      }
    };
    SchedulerBinding.instance.addTimingsCallback(_timingsCallback!);
  }

  @override
  void dispose() {
    final timingsCallback = _timingsCallback;
    if (timingsCallback != null) {
      SchedulerBinding.instance.removeTimingsCallback(timingsCallback);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class OptimizedVectorMapPainter extends CustomPainter {
  static const _geometrySimplificationToleranceSquared = 1.44;
  static const _motionGeometrySimplificationToleranceSquared = 4.0;

  const OptimizedVectorMapPainter({
    required this.camera,
    required this.terrainFeatures,
    required this.fishingSpots,
    this.texturePack = const GameMapTexturePack(),
    this.texturesEnabled = true,
  });

  final GameMapCamera camera;
  final List<TerrainVectorFeature> terrainFeatures;
  final List<ProjectedFishingSpot> fishingSpots;
  final GameMapTexturePack texturePack;
  final bool texturesEnabled;

  double get _activeGeometrySimplificationToleranceSquared => texturesEnabled
      ? _geometrySimplificationToleranceSquared
      : _motionGeometrySimplificationToleranceSquared;

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    final waterPaint = _surfaceFillPaint(
      TerrainKind.water,
      const ui.Color(0xFF24B9CC).withValues(alpha: 0.82),
    );
    final landPaint = _surfaceFillPaint(
      TerrainKind.land,
      const ui.Color(0xFF55B96F).withValues(alpha: 0.78),
    );
    final shorePaint = _surfaceFillPaint(
      TerrainKind.shore,
      const ui.Color(0xFFB9D878).withValues(alpha: 0.72),
    );
    _drawHydroAndLand(canvas, waterPaint, landPaint, shorePaint);
    _drawRoads(canvas);
    _drawBuildings(canvas);
    _drawFishingSpots(canvas);
  }

  void _drawHydroAndLand(
    ui.Canvas canvas,
    ui.Paint waterPaint,
    ui.Paint landPaint,
    ui.Paint shorePaint,
  ) {
    if (!texturesEnabled) {
      _drawMotionHydroAndLand(canvas, waterPaint, landPaint, shorePaint);
      return;
    }
    for (final feature in terrainFeatures) {
      if (feature.kind != TerrainKind.water &&
          feature.kind != TerrainKind.land &&
          feature.kind != TerrainKind.shore) {
        continue;
      }
      final path = ui.Path();
      _appendProjectedGeometry(path, feature);
      switch (feature.kind) {
        case TerrainKind.water:
          if (feature.isClosed && feature.points.length >= 3) {
            canvas.drawPath(path, waterPaint);
            canvas.drawPath(
              path,
              ui.Paint()
                ..color = const ui.Color(0xFFE7FFF0).withValues(alpha: 0.28)
                ..style = ui.PaintingStyle.stroke
                ..strokeWidth = 1.4
                ..strokeCap = ui.StrokeCap.round,
            );
          } else {
            canvas.drawPath(
              path,
              ui.Paint()
                ..color = const ui.Color(0xFF9FF5E8).withValues(alpha: 0.52)
                ..style = ui.PaintingStyle.stroke
                ..strokeWidth = 12
                ..strokeCap = ui.StrokeCap.round
                ..strokeJoin = ui.StrokeJoin.round,
            );
            canvas.drawPath(
              path,
              ui.Paint()
                ..color = const ui.Color(0xFFE7FFF0).withValues(alpha: 0.28)
                ..style = ui.PaintingStyle.stroke
                ..strokeWidth = 1.4
                ..strokeCap = ui.StrokeCap.round,
            );
          }
        case TerrainKind.land:
          canvas.drawPath(path, landPaint);
        case TerrainKind.shore:
          canvas.drawPath(path, shorePaint);
        case TerrainKind.road:
        case TerrainKind.pier:
        case TerrainKind.building:
        case TerrainKind.fishingNode:
      }
    }
  }

  void _drawMotionHydroAndLand(
    ui.Canvas canvas,
    ui.Paint waterPaint,
    ui.Paint landPaint,
    ui.Paint shorePaint,
  ) {
    final closedWaterPath = ui.Path();
    final openWaterPath = ui.Path();
    final landPath = ui.Path();
    final shorePath = ui.Path();

    for (final feature in terrainFeatures) {
      switch (feature.kind) {
        case TerrainKind.water:
          if (feature.isClosed && feature.points.length >= 3) {
            _appendProjectedGeometry(closedWaterPath, feature);
          } else {
            _appendProjectedGeometry(openWaterPath, feature);
          }
        case TerrainKind.land:
          _appendProjectedGeometry(landPath, feature);
        case TerrainKind.shore:
          _appendProjectedGeometry(shorePath, feature);
        case TerrainKind.road:
        case TerrainKind.pier:
        case TerrainKind.building:
        case TerrainKind.fishingNode:
      }
    }

    canvas.drawPath(closedWaterPath, waterPaint);
    canvas.drawPath(
      openWaterPath,
      ui.Paint()
        ..color = const ui.Color(0xFF9FF5E8).withValues(alpha: 0.52)
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = ui.StrokeCap.round
        ..strokeJoin = ui.StrokeJoin.round,
    );
    canvas.drawPath(landPath, landPaint);
    canvas.drawPath(shorePath, shorePaint);
    final waterOutlinePaint = ui.Paint()
      ..color = const ui.Color(0xFFE7FFF0).withValues(alpha: 0.28)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = ui.StrokeCap.round;
    canvas.drawPath(closedWaterPath, waterOutlinePaint);
    canvas.drawPath(openWaterPath, waterOutlinePaint);
  }

  void _drawRoads(ui.Canvas canvas) {
    final roadGroups = <RoadClass, ui.Path>{};
    final roadStyles = <RoadClass, GameRoadStyle>{};
    for (final feature in terrainFeatures) {
      if (feature.kind != TerrainKind.road ||
          !GameRoadStyle.isMainRoad(feature.roadClass, feature.name)) {
        continue;
      }
      final path = roadGroups.putIfAbsent(feature.roadClass, ui.Path.new);
      _appendProjectedGeometry(path, feature);
      roadStyles.putIfAbsent(
        feature.roadClass,
        () => GameRoadStyle.forFeature(feature),
      );
    }

    final orderedGroups = roadGroups.entries.toList()
      ..sort(
        (left, right) => roadStyles[left.key]!.drawPriority.compareTo(
              roadStyles[right.key]!.drawPriority,
            ),
      );
    for (final entry in orderedGroups) {
      final path = entry.value;
      final style =
          entry.key == RoadClass.motorway || entry.key == RoadClass.trunk
              ? roadStyles[entry.key]!.scaledBy(1.08)
              : roadStyles[entry.key]!;
      canvas.drawPath(
        path,
        ui.Paint()
          ..color = const ui.Color(0xFF224F49).withValues(alpha: 0.58)
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = style.casingWidth + 2
          ..strokeCap = ui.StrokeCap.round
          ..strokeJoin = ui.StrokeJoin.round,
      );
      canvas.drawPath(
        path,
        ui.Paint()
          ..color = _roadColor(entry.key)
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = style.surfaceWidth
          ..strokeCap = ui.StrokeCap.round
          ..strokeJoin = ui.StrokeJoin.round,
      );
    }
  }

  ui.Color _roadColor(RoadClass roadClass) => switch (roadClass) {
        RoadClass.motorway || RoadClass.trunk => const ui.Color(0xFFF4E8BB),
        RoadClass.primary => const ui.Color(0xFFFFF2C8),
        RoadClass.secondary => const ui.Color(0xFFE4EBD4),
        _ => const ui.Color(0xFFD8E6D8),
      };

  ui.Paint _surfaceFillPaint(TerrainKind kind, ui.Color fallbackColor) {
    final image = texturesEnabled ? texturePack.imageFor(kind) : null;
    if (image == null) {
      return ui.Paint()..color = fallbackColor;
    }
    final paint = ui.Paint()
      ..shader = ui.ImageShader(
        image,
        ui.TileMode.repeated,
        ui.TileMode.repeated,
        terrainWorldShaderTransform(
          imageSize: Size(image.width.toDouble(), image.height.toDouble()),
          camera: camera,
          tileWorldMeters: 300,
        ).storage,
      );
    if (kind == TerrainKind.land) {
      paint.colorFilter = const ui.ColorFilter.mode(
        ui.Color(0x66FFFFFF),
        ui.BlendMode.modulate,
      );
    }
    return paint;
  }

  void _drawBuildings(ui.Canvas canvas) {
    for (final feature in terrainFeatures) {
      if (feature.kind != TerrainKind.building ||
          !feature.isClosed ||
          feature.points.length < 3) {
        continue;
      }
      final path = _projectedPath(feature);
      if (path == null) continue;
      canvas.drawPath(
        path.shift(const ui.Offset(0, 3)),
        ui.Paint()..color = const ui.Color(0xFF245349).withValues(alpha: 0.35),
      );
      canvas.drawPath(
        path,
        ui.Paint()..color = const ui.Color(0xFFD7B879).withValues(alpha: 0.92),
      );
      canvas.drawPath(
        path,
        ui.Paint()
          ..color = const ui.Color(0xFF775238).withValues(alpha: 0.75)
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }
  }

  void _drawFishingSpots(ui.Canvas canvas) {
    final clusters = clusterProjectedFishingSpots(
      spots: fishingSpots,
      viewportSize: camera.viewportSize,
    );
    for (final cluster in clusters) {
      final spot = cluster.representative;
      final center = cluster.displayPosition;
      canvas.drawOval(
        ui.Rect.fromCenter(
          center: center.translate(0, 10),
          width: 58,
          height: 18,
        ),
        ui.Paint()..color = const ui.Color(0xFF073E4B).withValues(alpha: 0.24),
      );
      canvas.drawCircle(
        center.translate(0, -8),
        18,
        ui.Paint()..color = const ui.Color(0xFFFFE76B),
      );
      canvas.drawCircle(
        center.translate(0, -8),
        18,
        ui.Paint()
          ..color = const ui.Color(0xFF0B6872)
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 3,
      );
      canvas.drawCircle(
        center.translate(0, -8),
        7,
        ui.Paint()..color = const ui.Color(0xFFF9FFF5),
      );
      canvas.drawLine(
        center.translate(0, -28),
        center.translate(0, -44),
        ui.Paint()
          ..color = const ui.Color(0xFFFFF0A6)
          ..strokeWidth = 3
          ..strokeCap = ui.StrokeCap.round,
      );
      final label = TextPainter(
        text: TextSpan(
          text: cluster.count > 1
              ? '${spot.name} +${cluster.count - 1}'
              : spot.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: 124);
      final labelRect = ui.Rect.fromCenter(
        center: center.translate(0, 42),
        width: label.width + 14,
        height: 22,
      );
      canvas.drawRRect(
        ui.RRect.fromRectAndRadius(labelRect, const ui.Radius.circular(7)),
        ui.Paint()..color = const ui.Color(0xE6091D24),
      );
      label.paint(
        canvas,
        ui.Offset(labelRect.left + 7, labelRect.top + 5),
      );
    }
  }

  ui.Path? _projectedPath(TerrainVectorFeature feature) {
    if (feature.points.length < 2) return null;
    final path = ui.Path();
    _appendProjectedGeometry(path, feature);
    return path;
  }

  void _appendProjectedGeometry(
    ui.Path path,
    TerrainVectorFeature feature,
  ) {
    _appendSimplifiedProjectedPoints(path, feature);
    if (feature.isClosed) path.close();
  }

  void _appendSimplifiedProjectedPoints(
    ui.Path path,
    TerrainVectorFeature feature,
  ) {
    var hasProjectedPoint = false;
    var lastProjectedPoint = ui.Offset.zero;
    for (var index = 0; index < feature.points.length; index++) {
      final point = camera.project(feature.points[index]);
      final isLastPoint = index == feature.points.length - 1;
      final dx = point.dx - lastProjectedPoint.dx;
      final dy = point.dy - lastProjectedPoint.dy;
      if (!hasProjectedPoint ||
          isLastPoint ||
          dx * dx + dy * dy >= _activeGeometrySimplificationToleranceSquared) {
        if (!hasProjectedPoint) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
        lastProjectedPoint = point;
        hasProjectedPoint = true;
      }
    }
  }

  @override
  bool shouldRepaint(covariant OptimizedVectorMapPainter oldDelegate) {
    // During a gesture the map layer is projected once at the gesture-start
    // bearing and rotated as a composited layer. Ignore rebuilt list objects
    // while that frozen camera is active; GPS/viewport changes still repaint.
    if (!texturesEnabled &&
        !oldDelegate.texturesEnabled &&
        _sameCamera(oldDelegate.camera, camera)) {
      return false;
    }
    return oldDelegate.camera.bearingDegrees != camera.bearingDegrees ||
        oldDelegate.camera.viewportSize != camera.viewportSize ||
        oldDelegate.terrainFeatures != terrainFeatures ||
        oldDelegate.fishingSpots != fishingSpots ||
        oldDelegate.texturePack != texturePack ||
        oldDelegate.texturesEnabled != texturesEnabled;
  }

  bool _sameCamera(GameMapCamera left, GameMapCamera right) =>
      left.center == right.center &&
      left.visibleRadiusMeters == right.visibleRadiusMeters &&
      left.bearingDegrees == right.bearingDegrees &&
      left.viewportSize == right.viewportSize &&
      left.perspectiveStrength == right.perspectiveStrength &&
      left.viewportAnchorY == right.viewportAnchorY;
}
