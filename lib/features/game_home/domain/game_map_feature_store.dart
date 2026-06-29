import 'dart:ui';

import 'package:latlong2/latlong.dart';

import 'game_map_camera.dart';
import 'terrain_data_source.dart';

class GameMapFishingSpot {
  const GameMapFishingSpot({
    required this.id,
    required this.name,
    required this.position,
  });

  final String id;
  final String name;
  final LatLng position;
}

class ProjectedFishingSpot {
  const ProjectedFishingSpot({
    required this.id,
    required this.name,
    required this.position,
    required this.screenPosition,
  });

  final String id;
  final String name;
  final LatLng position;
  final Offset screenPosition;
}

class GameMapFeatureStore {
  const GameMapFeatureStore({required this.dataset});

  final GeoTerrainDataset dataset;

  List<TerrainVectorFeature> visibleTerrainFeatures(GameMapCamera camera) {
    return [
      for (final feature in dataset.features)
        if (_isVisibleTerrainFeature(camera, feature))
          TerrainVectorFeature(
            kind: feature.kind,
            name: feature.name,
            points: feature.geometry!.coordinates,
            isClosed: feature.geometry!.isPolygon,
          ),
    ];
  }

  List<ProjectedFishingSpot> projectFishingSpots({
    required GameMapCamera camera,
    required List<GameMapFishingSpot> spots,
  }) {
    return [
      for (final spot in spots)
        if (camera.isVisible(spot.position))
          ProjectedFishingSpot(
            id: spot.id,
            name: spot.name,
            position: spot.position,
            screenPosition: camera.project(spot.position),
          ),
    ];
  }

  bool _isVisibleTerrainFeature(
    GameMapCamera camera,
    GeoTerrainFeature feature,
  ) {
    final geometry = feature.geometry;
    if (geometry == null || geometry.coordinates.length < 2) return false;
    if (feature.kind == TerrainKind.fishingNode) return false;
    if (geometry.isPolygon &&
        _pointInPolygon(camera.center, geometry.coordinates)) {
      return true;
    }
    if (geometry.coordinates.any(camera.isVisible)) return true;
    if (_hasVisibleSegment(
      camera,
      geometry.coordinates,
      isClosed: geometry.isPolygon,
    )) {
      return true;
    }
    return camera.isVisible(
      feature.center,
      paddingMeters: feature.radiusMeters,
    );
  }

  bool _hasVisibleSegment(
    GameMapCamera camera,
    List<LatLng> points, {
    bool isClosed = false,
  }) {
    if (points.length < 2) return false;
    const padding = 80.0;
    final viewport = Rect.fromLTRB(
      -padding,
      -padding,
      camera.viewportSize.width + padding,
      camera.viewportSize.height + padding,
    );
    for (var i = 0; i < points.length - 1; i++) {
      if (_segmentIntersectsRect(
        camera.project(points[i]),
        camera.project(points[i + 1]),
        viewport,
      )) {
        return true;
      }
    }
    if (isClosed && points.length > 2) {
      return _segmentIntersectsRect(
        camera.project(points.last),
        camera.project(points.first),
        viewport,
      );
    }
    return false;
  }

  bool _segmentIntersectsRect(Offset a, Offset b, Rect rect) {
    if (rect.contains(a) || rect.contains(b)) return true;
    final topLeft = rect.topLeft;
    final topRight = rect.topRight;
    final bottomRight = rect.bottomRight;
    final bottomLeft = rect.bottomLeft;
    return _segmentsIntersect(a, b, topLeft, topRight) ||
        _segmentsIntersect(a, b, topRight, bottomRight) ||
        _segmentsIntersect(a, b, bottomRight, bottomLeft) ||
        _segmentsIntersect(a, b, bottomLeft, topLeft);
  }

  bool _segmentsIntersect(Offset a, Offset b, Offset c, Offset d) {
    final abC = _orientation(a, b, c);
    final abD = _orientation(a, b, d);
    final cdA = _orientation(c, d, a);
    final cdB = _orientation(c, d, b);

    if (abC == 0 && _pointOnSegment(c, a, b)) return true;
    if (abD == 0 && _pointOnSegment(d, a, b)) return true;
    if (cdA == 0 && _pointOnSegment(a, c, d)) return true;
    if (cdB == 0 && _pointOnSegment(b, c, d)) return true;

    return abC != abD && cdA != cdB;
  }

  int _orientation(Offset a, Offset b, Offset c) {
    const epsilon = 0.000001;
    final cross = (b.dx - a.dx) * (c.dy - a.dy) - (b.dy - a.dy) * (c.dx - a.dx);
    if (cross.abs() < epsilon) return 0;
    return cross > 0 ? 1 : -1;
  }

  bool _pointOnSegment(Offset point, Offset a, Offset b) {
    const epsilon = 0.000001;
    return point.dx >= _min(a.dx, b.dx) - epsilon &&
        point.dx <= _max(a.dx, b.dx) + epsilon &&
        point.dy >= _min(a.dy, b.dy) - epsilon &&
        point.dy <= _max(a.dy, b.dy) + epsilon;
  }

  double _min(double a, double b) => a < b ? a : b;

  double _max(double a, double b) => a > b ? a : b;

  bool _pointInPolygon(LatLng point, List<LatLng> polygon) {
    if (polygon.length < 3) return false;
    var inside = false;
    for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final xi = polygon[i].longitude;
      final yi = polygon[i].latitude;
      final xj = polygon[j].longitude;
      final yj = polygon[j].latitude;
      final intersects = ((yi > point.latitude) != (yj > point.latitude)) &&
          (point.longitude <
              (xj - xi) * (point.latitude - yi) / (yj - yi) + xi);
      if (intersects) inside = !inside;
    }
    return inside;
  }
}
