import 'dart:math' as math;
import 'dart:ui';

import 'package:latlong2/latlong.dart';

class GameMapCamera {
  const GameMapCamera({
    required this.center,
    required this.visibleRadiusMeters,
    required this.bearingDegrees,
    required this.viewportSize,
  });

  final LatLng center;
  final double visibleRadiusMeters;

  /// Clockwise visual map rotation around the player.
  ///
  /// At 90 degrees, a point north of the player projects to the right.
  final double bearingDegrees;
  final Size viewportSize;

  Offset get viewportCenter =>
      Offset(viewportSize.width * 0.5, viewportSize.height * 0.5);

  Offset project(LatLng point) {
    final meters = _metersFromCenter(point);
    final rotated = _rotate(meters, bearingDegrees);
    final pixelsPerMeter = _pixelsPerMeter;
    return Offset(
      viewportCenter.dx + rotated.dx * pixelsPerMeter,
      viewportCenter.dy - rotated.dy * pixelsPerMeter,
    );
  }

  bool isVisible(LatLng point, {double paddingMeters = 120}) {
    final projected = project(point);
    final paddingPixels = _paddingPixels(paddingMeters);
    return projected.dx >= -paddingPixels &&
        projected.dx <= viewportSize.width + paddingPixels &&
        projected.dy >= -paddingPixels &&
        projected.dy <= viewportSize.height + paddingPixels;
  }

  double get _pixelsPerMeter =>
      math.min(viewportSize.width, viewportSize.height) /
      (visibleRadiusMeters * 2);

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
}
