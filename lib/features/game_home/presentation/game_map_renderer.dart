import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../domain/game_map_camera.dart';
import '../domain/game_map_feature_store.dart';
import '../domain/terrain_data_source.dart';

class _ProjectedTerrainTile {
  const _ProjectedTerrainTile(this.data, this.center);

  final TerrainTile data;
  final Offset center;
}

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
    final projectedTiles = [
      for (final tile in terrainTiles)
        if (camera.isVisible(tile.centerLatLng, paddingMeters: 80))
          _ProjectedTerrainTile(tile, camera.project(tile.centerLatLng)),
    ];

    _drawSoftTerrainTiles(
      canvas,
      projectedTiles
          .where((tile) =>
              tile.data.kind == TerrainKind.land ||
              tile.data.kind == TerrainKind.shore)
          .toList(),
      tileWidth,
      tileHeight,
    );
    if (!terrainFeatures.any((feature) => feature.kind == TerrainKind.road)) {
      _drawFallbackRoads(
        canvas,
        projectedTiles
            .where((tile) => tile.data.kind == TerrainKind.road)
            .toList(),
        tileWidth,
      );
    }
    _drawFallbackPiers(
      canvas,
      projectedTiles
          .where((tile) => tile.data.kind == TerrainKind.pier)
          .toList(),
      tileWidth,
      tileHeight,
    );
    for (final tile in terrainTiles) {
      if (tile.kind != TerrainKind.fishingNode) continue;
      if (!camera.isVisible(tile.centerLatLng, paddingMeters: 80)) {
        continue;
      }
      final center = camera.project(tile.centerLatLng);
      _drawFallbackNode(canvas, center, tileWidth);
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

  void _drawSoftTerrainTiles(
    Canvas canvas,
    List<_ProjectedTerrainTile> tiles,
    double tileWidth,
    double tileHeight,
  ) {
    for (final tile in tiles) {
      final isShore = tile.data.kind == TerrainKind.shore;
      final radius = isShore ? tileWidth * 0.88 : tileWidth * 1.15;
      final rect = Rect.fromCenter(
        center: tile.center,
        width: radius * 1.65,
        height: tileHeight * (isShore ? 1.45 : 1.9),
      );
      canvas.drawOval(
        rect,
        Paint()
          ..color =
              (isShore ? const Color(0xFFEED98A) : const Color(0xFF45C772))
                  .withValues(alpha: isShore ? 0.18 : 0.2)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
    }
  }

  void _drawFallbackRoads(
    Canvas canvas,
    List<_ProjectedTerrainTile> roadTiles,
    double tileWidth,
  ) {
    if (roadTiles.isEmpty) return;
    final roadPath = Path();
    for (var i = 0; i < roadTiles.length; i++) {
      final current = roadTiles[i];
      _ProjectedTerrainTile? nearest;
      var nearestDistance = double.infinity;
      for (var j = i + 1; j < roadTiles.length; j++) {
        final candidate = roadTiles[j];
        final distance = (candidate.center - current.center).distance;
        if (distance < nearestDistance && distance <= tileWidth * 1.55) {
          nearest = candidate;
          nearestDistance = distance;
        }
      }
      if (nearest == null) continue;
      roadPath
        ..moveTo(current.center.dx, current.center.dy)
        ..lineTo(nearest.center.dx, nearest.center.dy);
    }
    if (roadPath.getBounds().isEmpty) return;
    canvas.drawPath(
      roadPath,
      Paint()
        ..color = const Color(0xFF08303A).withValues(alpha: 0.58)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      roadPath,
      Paint()
        ..color = const Color(0xFFFFD45C).withValues(alpha: 0.68)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _drawFallbackPiers(
    Canvas canvas,
    List<_ProjectedTerrainTile> pierTiles,
    double tileWidth,
    double tileHeight,
  ) {
    final paint = Paint()
      ..color = const Color(0xFFFFC982).withValues(alpha: 0.38)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    for (final tile in pierTiles) {
      canvas.drawLine(
        tile.center.translate(0, -tileHeight * 0.38),
        tile.center.translate(0, tileHeight * 0.38),
        paint,
      );
    }
  }

  void _drawFallbackNode(Canvas canvas, Offset center, double tileWidth) {
    canvas.drawCircle(
      center,
      tileWidth * 0.18,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFF36D).withValues(alpha: 0.42),
            const Color(0xFFFFF36D).withValues(alpha: 0),
          ],
        ).createShader(
          Rect.fromCircle(center: center, radius: tileWidth * 0.18),
        ),
    );
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
