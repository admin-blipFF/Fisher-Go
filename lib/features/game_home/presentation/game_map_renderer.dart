import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../domain/game_map_camera.dart';
import '../domain/game_map_feature_store.dart';
import '../domain/terrain_data_source.dart';

class GameMapRenderer extends StatelessWidget {
  const GameMapRenderer({
    super.key,
    required this.camera,
    required this.terrainFeatures,
    required this.fishingSpots,
  });

  final GameMapCamera camera;
  final List<TerrainVectorFeature> terrainFeatures;
  final List<ProjectedFishingSpot> fishingSpots;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: GameMapPainter(
        camera: camera,
        terrainFeatures: terrainFeatures,
        fishingSpots: fishingSpots,
      ),
      size: Size.infinite,
    );
  }
}

class GameMapPainter extends CustomPainter {
  const GameMapPainter({
    required this.camera,
    required this.terrainFeatures,
    required this.fishingSpots,
  });

  final GameMapCamera camera;
  final List<TerrainVectorFeature> terrainFeatures;
  final List<ProjectedFishingSpot> fishingSpots;

  @override
  void paint(Canvas canvas, Size size) {
    _drawMapBase(canvas, size);
    for (final feature in terrainFeatures) {
      final path = _pathForFeature(feature);
      if (path == null) continue;
      switch (feature.kind) {
        case TerrainKind.water:
          _drawWaterFeature(canvas, path, feature.isClosed);
        case TerrainKind.land:
        case TerrainKind.shore:
          _drawLandFeature(canvas, path, feature.isClosed);
        case TerrainKind.road:
          _drawRoadFeature(canvas, path);
        case TerrainKind.pier:
          _drawPierFeature(canvas, path);
        case TerrainKind.fishingNode:
          break;
      }
    }
    for (final spot in fishingSpots) {
      _drawFishingSpotGlow(canvas, spot.screenPosition);
    }
    _drawDepthOverlay(canvas, size);
  }

  void _drawMapBase(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF72D5D0),
            Color(0xFF35B9B2),
            Color(0xFF52C879),
            Color(0xFF238F65),
          ],
          stops: [0, 0.34, 0.58, 1],
        ).createShader(rect),
    );

    final waterPaint = Paint()
      ..color = const Color(0xFF0C8EA4).withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 14; i++) {
      final y = size.height * (0.08 + i * 0.055);
      final path = Path()
        ..moveTo(-size.width * 0.1, y)
        ..cubicTo(
          size.width * 0.18,
          y - 16,
          size.width * 0.38,
          y + 20,
          size.width * 0.68,
          y - 4,
        )
        ..quadraticBezierTo(
          size.width * 0.86,
          y - 18,
          size.width * 1.1,
          y + 2,
        );
      canvas.drawPath(path, waterPaint);
    }
  }

  Path? _pathForFeature(TerrainVectorFeature feature) {
    if (feature.points.length < 2) return null;
    final path = Path();
    for (var i = 0; i < feature.points.length; i++) {
      final offset = camera.project(feature.points[i]);
      if (i == 0) {
        path.moveTo(offset.dx, offset.dy);
      } else {
        path.lineTo(offset.dx, offset.dy);
      }
    }
    if (feature.isClosed) path.close();
    return path;
  }

  void _drawWaterFeature(Canvas canvas, Path path, bool isClosed) {
    if (isClosed) {
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF0A7E99).withValues(alpha: 0.2)
          ..style = PaintingStyle.fill,
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFE3FBFF).withValues(alpha: 0.34)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _drawLandFeature(Canvas canvas, Path path, bool isClosed) {
    if (isClosed) {
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFFE8F2A5).withValues(alpha: 0.16)
          ..style = PaintingStyle.fill,
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFE8F8CF).withValues(alpha: 0.48)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF0A6D7D).withValues(alpha: 0.48)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _drawRoadFeature(Canvas canvas, Path path) {
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF0C3F48).withValues(alpha: 0.72)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFFFC94A).withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.72)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _drawPierFeature(Canvas canvas, Path path) {
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF8A4D25).withValues(alpha: 0.72)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFFFE49A).withValues(alpha: 0.68)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.7
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _drawFishingSpotGlow(Canvas canvas, Offset center) {
    canvas.drawCircle(
      center,
      24,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFF36D).withValues(alpha: 0.48),
            const Color(0xFFFFF36D).withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: 24)),
    );
    canvas.drawCircle(
      center,
      8,
      Paint()..color = const Color(0xFFFFF7A8).withValues(alpha: 0.74),
    );
  }

  void _drawDepthOverlay(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF062B3D).withValues(alpha: 0.08),
            Colors.transparent,
            const Color(0xFF031C1F).withValues(alpha: 0.28),
          ],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant GameMapPainter oldDelegate) =>
      !_sameCamera(oldDelegate.camera, camera) ||
      !_sameTerrainFeatures(oldDelegate.terrainFeatures, terrainFeatures) ||
      !_sameFishingSpots(oldDelegate.fishingSpots, fishingSpots);

  bool _sameCamera(GameMapCamera a, GameMapCamera b) =>
      a.center.latitude == b.center.latitude &&
      a.center.longitude == b.center.longitude &&
      a.visibleRadiusMeters == b.visibleRadiusMeters &&
      a.bearingDegrees == b.bearingDegrees &&
      a.viewportSize == b.viewportSize;

  bool _sameTerrainFeatures(
    List<TerrainVectorFeature> a,
    List<TerrainVectorFeature> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final left = a[i];
      final right = b[i];
      if (left.kind != right.kind ||
          left.name != right.name ||
          left.isClosed != right.isClosed ||
          !_sameLatLngList(left.points, right.points)) {
        return false;
      }
    }
    return true;
  }

  bool _sameFishingSpots(
    List<ProjectedFishingSpot> a,
    List<ProjectedFishingSpot> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final left = a[i];
      final right = b[i];
      if (left.id != right.id ||
          left.name != right.name ||
          left.position.latitude != right.position.latitude ||
          left.position.longitude != right.position.longitude ||
          left.screenPosition != right.screenPosition) {
        return false;
      }
    }
    return true;
  }

  bool _sameLatLngList(List<LatLng> a, List<LatLng> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].latitude != b[i].latitude || a[i].longitude != b[i].longitude) {
        return false;
      }
    }
    return true;
  }
}
