import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../domain/game_map_camera.dart';
import '../domain/game_map_feature_store.dart';
import '../domain/terrain_data_source.dart';

class GameMapRenderer extends StatelessWidget {
  const GameMapRenderer({
    super.key,
    required this.camera,
    required this.terrainTiles,
    required this.terrainFeatures,
    required this.fishingSpots,
  });

  final GameMapCamera camera;
  final List<TerrainTile> terrainTiles;
  final List<TerrainVectorFeature> terrainFeatures;
  final List<ProjectedFishingSpot> fishingSpots;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: GameMapPainter(
        camera: camera,
        terrainTiles: terrainTiles,
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
    required this.terrainTiles,
    required this.terrainFeatures,
    required this.fishingSpots,
  });

  final GameMapCamera camera;
  final List<TerrainTile> terrainTiles;
  final List<TerrainVectorFeature> terrainFeatures;
  final List<ProjectedFishingSpot> fishingSpots;

  @override
  void paint(Canvas canvas, Size size) {
    _drawSeaLayer(canvas, size);
    _drawFallbackTileLayer(canvas, size);
    _drawLandLayer(canvas, size);
    _drawCoastlineLayer(canvas, size);
    _drawRoadLayer(canvas, size);
    _drawPierLayer(canvas, size);
    _drawFishingSpotLayer(canvas, size);
    _drawAtmosphereLayer(canvas, size);
  }

  void _drawFallbackTileLayer(Canvas canvas, Size size) {
    if (terrainTiles.isEmpty) return;
    final tileWidth = camera.viewportSize.shortestSide / 7.2;
    final tileHeight = camera.viewportSize.shortestSide / 10.5;
    for (final tile in terrainTiles) {
      if (!camera.isVisible(tile.centerLatLng, paddingMeters: 80)) continue;
      final center = camera.project(tile.centerLatLng);
      final path = Path()
        ..moveTo(center.dx, center.dy - tileHeight * 0.5)
        ..lineTo(center.dx + tileWidth * 0.5, center.dy)
        ..lineTo(center.dx, center.dy + tileHeight * 0.5)
        ..lineTo(center.dx - tileWidth * 0.5, center.dy)
        ..close();
      canvas.drawPath(path, _tilePaint(tile.kind, path.getBounds()));
      _drawTileTexture(canvas, tile.kind, center, tileWidth, tileHeight);
    }
  }

  void _drawSeaLayer(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF6BE5E0),
            Color(0xFF28B9CC),
            Color(0xFF1D9DB5),
            Color(0xFF147B93),
          ],
          stops: [0, 0.36, 0.72, 1],
        ).createShader(rect),
    );

    for (final feature in terrainFeatures) {
      if (feature.kind != TerrainKind.water) continue;
      final path = _pathForFeature(feature);
      if (path == null) continue;
      if (feature.isClosed) {
        canvas.drawPath(
          path,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF7AF5EF).withValues(alpha: 0.18),
                const Color(0xFF036C8C).withValues(alpha: 0.42),
              ],
            ).createShader(path.getBounds())
            ..style = PaintingStyle.fill,
        );
      }
    }

    final wavePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.13)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 16; i++) {
      final y = size.height * (0.07 + i * 0.057);
      final xShift = (i.isEven ? -0.12 : -0.02) * size.width;
      final path = Path()
        ..moveTo(xShift, y)
        ..cubicTo(
          size.width * 0.18,
          y - 13,
          size.width * 0.38,
          y + 16,
          size.width * 0.64,
          y - 3,
        )
        ..quadraticBezierTo(
          size.width * 0.83,
          y - 18,
          size.width * 1.14,
          y + 4,
        );
      canvas.drawPath(path, wavePaint);
    }
  }

  void _drawLandLayer(Canvas canvas, Size size) {
    for (final feature in terrainFeatures) {
      if (feature.kind != TerrainKind.land &&
          feature.kind != TerrainKind.shore) {
        continue;
      }
      final path = _pathForFeature(feature);
      if (path == null) continue;
      if (feature.isClosed) {
        canvas.drawPath(
          path,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFFB7F06B).withValues(alpha: 0.62),
                const Color(0xFF55C76B).withValues(alpha: 0.58),
                const Color(0xFF2FAE77).withValues(alpha: 0.5),
              ],
            ).createShader(path.getBounds())
            ..style = PaintingStyle.fill,
        );
      }

      _drawLandTexture(canvas, path);
    }
  }

  Paint _tilePaint(TerrainKind kind, Rect bounds) {
    final colors = switch (kind) {
      TerrainKind.water => [
          const Color(0xFF1AD3D7).withValues(alpha: 0.18),
          const Color(0xFF0790B0).withValues(alpha: 0.2),
        ],
      TerrainKind.shore => [
          const Color(0xFFEED98A).withValues(alpha: 0.34),
          const Color(0xFF7FD99E).withValues(alpha: 0.24),
        ],
      TerrainKind.land => [
          const Color(0xFF76D85E).withValues(alpha: 0.38),
          const Color(0xFF2EA967).withValues(alpha: 0.32),
        ],
      TerrainKind.road => [
          const Color(0xFFFFD45C).withValues(alpha: 0.58),
          const Color(0xFFC19B47).withValues(alpha: 0.48),
        ],
      TerrainKind.pier => [
          const Color(0xFFC47A42).withValues(alpha: 0.48),
          const Color(0xFF70503A).withValues(alpha: 0.42),
        ],
      TerrainKind.fishingNode => [
          const Color(0xFFFFF36D).withValues(alpha: 0.5),
          const Color(0xFF17D7C7).withValues(alpha: 0.28),
        ],
    };
    return Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors,
      ).createShader(bounds);
  }

  void _drawTileTexture(
    Canvas canvas,
    TerrainKind kind,
    Offset center,
    double tileWidth,
    double tileHeight,
  ) {
    switch (kind) {
      case TerrainKind.water:
        final paint = Paint()
          ..color = Colors.white.withValues(alpha: 0.12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..strokeCap = StrokeCap.round;
        canvas.drawArc(
          Rect.fromCenter(
            center: center,
            width: tileWidth * 0.48,
            height: tileHeight * 0.26,
          ),
          0.15,
          2.6,
          false,
          paint,
        );
      case TerrainKind.shore:
        canvas.drawCircle(
          center,
          tileWidth * 0.08,
          Paint()..color = const Color(0xFFFFF5C8).withValues(alpha: 0.22),
        );
      case TerrainKind.land:
        final paint = Paint()
          ..color = const Color(0xFFDDFB78).withValues(alpha: 0.16)
          ..strokeWidth = 1
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
          center.translate(-tileWidth * 0.16, tileHeight * 0.08),
          center.translate(-tileWidth * 0.04, -tileHeight * 0.14),
          paint,
        );
        canvas.drawLine(
          center.translate(tileWidth * 0.05, tileHeight * 0.12),
          center.translate(tileWidth * 0.18, -tileHeight * 0.08),
          paint,
        );
      case TerrainKind.road:
        final edge = Paint()
          ..color = const Color(0xFF092D36).withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round;
        final centerPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.58)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round;
        final a = center.translate(-tileWidth * 0.34, 0);
        final b = center.translate(tileWidth * 0.34, 0);
        canvas.drawLine(a, b, edge);
        canvas.drawLine(a, b, centerPaint);
      case TerrainKind.pier:
        final paint = Paint()
          ..color = const Color(0xFFFFD79A).withValues(alpha: 0.3)
          ..strokeWidth = 1.2;
        for (var i = -1; i <= 1; i++) {
          final dx = i * tileWidth * 0.12;
          canvas.drawLine(
            center.translate(dx, -tileHeight * 0.28),
            center.translate(dx, tileHeight * 0.28),
            paint,
          );
        }
      case TerrainKind.fishingNode:
        canvas.drawCircle(
          center,
          tileWidth * 0.18,
          Paint()
            ..shader = RadialGradient(
              colors: [
                const Color(0xFFFFF36D).withValues(alpha: 0.42),
                const Color(0xFFFFF36D).withValues(alpha: 0),
              ],
            ).createShader(Rect.fromCircle(
              center: center,
              radius: tileWidth * 0.18,
            )),
        );
    }
  }

  void _drawCoastlineLayer(Canvas canvas, Size size) {
    for (final feature in terrainFeatures) {
      if (feature.kind != TerrainKind.water &&
          feature.kind != TerrainKind.land &&
          feature.kind != TerrainKind.shore) {
        continue;
      }
      final path = _pathForFeature(feature);
      if (path == null) continue;

      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFFEFFFD8).withValues(alpha: 0.56)
          ..style = PaintingStyle.stroke
          ..strokeWidth = feature.kind == TerrainKind.water ? 2.4 : 6.0
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF0A7284).withValues(alpha: 0.46)
          ..style = PaintingStyle.stroke
          ..strokeWidth = feature.kind == TerrainKind.water ? 1.2 : 2.0
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  void _drawRoadLayer(Canvas canvas, Size size) {
    for (final feature in terrainFeatures) {
      if (feature.kind != TerrainKind.road) continue;
      final path = _pathForFeature(feature);
      if (path == null) continue;

      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF0A3945).withValues(alpha: 0.72)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFFFFCF52).withValues(alpha: 0.92)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5.8
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.76)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  void _drawPierLayer(Canvas canvas, Size size) {
    for (final feature in terrainFeatures) {
      if (feature.kind != TerrainKind.pier) continue;
      final path = _pathForFeature(feature);
      if (path == null) continue;

      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF3F2B24).withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.square
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFFC47A42).withValues(alpha: 0.78)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFFFFE6A9).withValues(alpha: 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  void _drawFishingSpotLayer(Canvas canvas, Size size) {
    for (final spot in fishingSpots) {
      _drawFishingSpotMarker(canvas, spot.screenPosition);
    }
  }

  void _drawAtmosphereLayer(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFFFFFFF).withValues(alpha: 0.06),
            Colors.transparent,
            const Color(0xFF022C39).withValues(alpha: 0.28),
          ],
          stops: const [0, 0.48, 1],
        ).createShader(rect),
    );

    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.53),
      size.shortestSide * 0.46,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1,
    );
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

  void _drawLandTexture(Canvas canvas, Path path) {
    final bounds = path.getBounds();
    if (bounds.isEmpty) return;
    final grassPaint = Paint()
      ..color = const Color(0xFFE2FF8B).withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    for (var x = bounds.left; x < bounds.right; x += 22) {
      final start = Offset(x, bounds.top + 10);
      final end = Offset(x + 14, bounds.bottom - 8);
      canvas.drawLine(start, end, grassPaint);
    }
  }

  void _drawFishingSpotMarker(Canvas canvas, Offset center) {
    canvas.drawPath(
      Path()
        ..moveTo(center.dx, center.dy - 36)
        ..quadraticBezierTo(
            center.dx + 18, center.dy - 28, center.dx + 9, center.dy - 10)
        ..quadraticBezierTo(center.dx + 4, center.dy - 2, center.dx, center.dy)
        ..quadraticBezierTo(
            center.dx - 4, center.dy - 2, center.dx - 9, center.dy - 10)
        ..quadraticBezierTo(
            center.dx - 18, center.dy - 28, center.dx, center.dy - 36)
        ..close(),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFF570), Color(0xFF12D6C6)],
        ).createShader(Rect.fromCircle(center: center, radius: 36)),
    );
    canvas.drawCircle(
      center.translate(0, -21),
      8,
      Paint()
        ..color = const Color(0xFF062E38).withValues(alpha: 0.62)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawCircle(
      center.translate(0, -21),
      27,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFF36D).withValues(alpha: 0.35),
            const Color(0xFFFFF36D).withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: 27)),
    );
    canvas.drawCircle(
      center.translate(0, 2),
      16,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFF36D).withValues(alpha: 0.28),
            const Color(0xFFFFF36D).withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: 16)),
    );
  }

  @override
  bool shouldRepaint(covariant GameMapPainter oldDelegate) =>
      !_sameCamera(oldDelegate.camera, camera) ||
      !_sameTerrainTiles(oldDelegate.terrainTiles, terrainTiles) ||
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

  bool _sameTerrainTiles(List<TerrainTile> a, List<TerrainTile> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
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
