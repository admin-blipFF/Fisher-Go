import 'dart:math' as math;
import 'dart:ui';

import 'package:latlong2/latlong.dart';

class GameMapGridLayout {
  const GameMapGridLayout({required this.rows, required this.cols});

  factory GameMapGridLayout.forViewport(
    Size viewportSize, {
    int verticalCellCount = 28,
  }) {
    final safeHeight = viewportSize.height <= 0 ? 1.0 : viewportSize.height;
    final aspectRatio = viewportSize.width / safeHeight;
    final horizontalCellCount =
        math.max(8, (verticalCellCount * aspectRatio).ceil());
    return GameMapGridLayout(
      rows: verticalCellCount + 1,
      cols: horizontalCellCount + 1,
    );
  }

  final int rows;
  final int cols;
}

class GameMapCamera {
  const GameMapCamera({
    required this.center,
    required this.visibleRadiusMeters,
    required this.bearingDegrees,
    required this.viewportSize,
    this.perspectiveStrength = 0,
    this.viewportAnchorY = 0.5,
  });

  final LatLng center;
  final double visibleRadiusMeters;

  /// Clockwise visual map rotation around the player.
  ///
  /// At 90 degrees, a point north of the player projects to the right.
  final double bearingDegrees;
  final Size viewportSize;
  final double perspectiveStrength;
  final double viewportAnchorY;

  Offset get viewportCenter =>
      Offset(viewportSize.width * 0.5, viewportSize.height * viewportAnchorY);

  Offset project(LatLng point) {
    final meters = _metersFromCenter(point);
    final rotated = _rotate(meters, bearingDegrees);
    final pixelsPerMeter = _pixelsPerMeter;
    final depthScale = _depthScale(rotated);
    return Offset(
      viewportCenter.dx + rotated.dx * pixelsPerMeter * depthScale,
      viewportCenter.dy - rotated.dy * pixelsPerMeter * depthScale,
    );
  }

  double depthScaleFor(LatLng point) {
    final meters = _metersFromCenter(point);
    return _depthScale(_rotate(meters, bearingDegrees));
  }

  bool isVisible(LatLng point, {double paddingMeters = 450}) {
    final projected = project(point);
    final paddingPixels = _paddingPixels(paddingMeters);
    return projected.dx >= -paddingPixels &&
        projected.dx <= viewportSize.width + paddingPixels &&
        projected.dy >= -paddingPixels &&
        projected.dy <= viewportSize.height + paddingPixels;
  }

  double get _pixelsPerMeter => viewportSize.height / (visibleRadiusMeters * 2);

  double _paddingPixels(double paddingMeters) =>
      paddingMeters * _pixelsPerMeter;

  Offset _metersFromCenter(LatLng point) {
    const metersPerDegreeLat = 111320.0;
    final metersPerDegreeLng =
        111320.0 * math.cos(center.latitude * math.pi / 180);
    return Offset(
      (point.longitude - center.longitude) * metersPerDegreeLng,
      (point.latitude - center.latitude) * metersPerDegreeLat,
    );
  }

  Offset _rotate(Offset meters, double degrees) {
    final radians = degrees * math.pi / 180;
    final cosA = math.cos(radians);
    final sinA = math.sin(radians);
    return Offset(
      meters.dx * cosA + meters.dy * sinA,
      -meters.dx * sinA + meters.dy * cosA,
    );
  }

  double _depthScale(Offset rotatedMeters) {
    if (perspectiveStrength == 0) return 1;
    final normalizedDepth =
        (rotatedMeters.dy / visibleRadiusMeters).clamp(-1.0, 1.0);
    return (1 - normalizedDepth * perspectiveStrength).clamp(0.68, 1.32);
  }
}
