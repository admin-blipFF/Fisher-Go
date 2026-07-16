import 'dart:ui';

import 'package:latlong2/latlong.dart';

import 'game_map_camera.dart';
import 'game_road_style.dart';
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

class ProjectedFishingSpotCluster {
  const ProjectedFishingSpotCluster({
    required this.representative,
    required this.members,
    required this.displayPosition,
  });

  final ProjectedFishingSpot representative;
  final List<ProjectedFishingSpot> members;
  final Offset displayPosition;

  int get count => members.length;
}

List<ProjectedFishingSpotCluster> clusterProjectedFishingSpots({
  required List<ProjectedFishingSpot> spots,
  required Size viewportSize,
  double mergeDistance = 112,
}) {
  if (spots.isEmpty || viewportSize.isEmpty) return const [];

  final minX = viewportSize.width < 118 ? viewportSize.width / 2 : 59.0;
  final maxX = viewportSize.width < 182
      ? viewportSize.width / 2
      : viewportSize.width - 123;
  final minY = viewportSize.height < 274 ? viewportSize.height / 2 : 145.0;
  final maxY = viewportSize.height < 260
      ? viewportSize.height / 2
      : viewportSize.height - 130;
  final visibleSpots = spots.where((spot) {
    final position = spot.screenPosition;
    return position.dx >= -60 &&
        position.dx <= viewportSize.width + 60 &&
        position.dy >= 72 &&
        position.dy <= viewportSize.height - 90;
  }).toList()
    ..sort((left, right) =>
        right.screenPosition.dy.compareTo(left.screenPosition.dy));

  final clusters = <_MutableProjectedFishingSpotCluster>[];
  for (final spot in visibleSpots) {
    final displayPosition = Offset(
      spot.screenPosition.dx.clamp(minX, maxX),
      spot.screenPosition.dy.clamp(minY, maxY),
    );
    final matchingCluster =
        clusters.cast<_MutableProjectedFishingSpotCluster?>().firstWhere(
              (cluster) =>
                  (cluster!.displayPosition - displayPosition).distance <
                  mergeDistance,
              orElse: () => null,
            );
    if (matchingCluster == null) {
      clusters.add(
        _MutableProjectedFishingSpotCluster(
          representative: spot,
          displayPosition: displayPosition,
        ),
      );
    } else {
      matchingCluster.members.add(spot);
    }
  }

  final result = [
    for (final cluster in clusters)
      ProjectedFishingSpotCluster(
        representative: cluster.representative,
        members: List.unmodifiable(cluster.members),
        displayPosition: cluster.displayPosition,
      ),
  ];
  result.sort((left, right) =>
      left.displayPosition.dy.compareTo(right.displayPosition.dy));
  return result;
}

class _MutableProjectedFishingSpotCluster {
  _MutableProjectedFishingSpotCluster({
    required this.representative,
    required this.displayPosition,
  }) : members = [representative];

  final ProjectedFishingSpot representative;
  final List<ProjectedFishingSpot> members;
  final Offset displayPosition;
}

class GameMapFeatureStore {
  GameMapFeatureStore({required this.dataset})
      : _indexedFeatures = _indexCache[dataset] ??= [
          for (final feature in dataset.features)
            _IndexedTerrainFeature(feature),
        ];

  static final _indexCache = Expando<List<_IndexedTerrainFeature>>();
  final GeoTerrainDataset dataset;
  final List<_IndexedTerrainFeature> _indexedFeatures;

  List<TerrainVectorFeature> visibleTerrainFeatures(GameMapCamera camera) {
    return [
      for (final indexed in _candidateFeatures(camera))
        if (indexed.feature case final feature)
          if (_isVisibleTerrainFeature(camera, feature) &&
              (feature.kind != TerrainKind.road ||
                  GameRoadStyle.isMainRoad(feature.roadClass, feature.name)))
            TerrainVectorFeature(
              kind: feature.kind,
              name: feature.name,
              points: feature.geometry!.coordinates,
              isClosed: feature.geometry!.isPolygon,
              provenance: feature.provenance,
              osmId: feature.osmId,
              heightMeters: feature.heightMeters,
              roadClass: feature.roadClass,
              isBridge: feature.isBridge,
              lanes: feature.lanes,
            ),
    ];
  }

  int candidateFeatureCount(GameMapCamera camera) =>
      _candidateFeatures(camera).length;

  List<_IndexedTerrainFeature> _candidateFeatures(GameMapCamera camera) {
    final searchRadiusMeters = camera.visibleRadiusMeters + 550;
    final latitudePadding = searchRadiusMeters / 111320;
    final longitudePadding = searchRadiusMeters / 100000;
    final minLat = camera.center.latitude - latitudePadding;
    final maxLat = camera.center.latitude + latitudePadding;
    final minLng = camera.center.longitude - longitudePadding;
    final maxLng = camera.center.longitude + longitudePadding;
    return [
      for (final indexed in _indexedFeatures)
        if (indexed.intersects(minLat, maxLat, minLng, maxLng)) indexed,
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

class _IndexedTerrainFeature {
  _IndexedTerrainFeature(this.feature)
      : minLat = _minimumLatitude(feature),
        maxLat = _maximumLatitude(feature),
        minLng = _minimumLongitude(feature),
        maxLng = _maximumLongitude(feature);

  final GeoTerrainFeature feature;
  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;

  bool intersects(
    double viewportMinLat,
    double viewportMaxLat,
    double viewportMinLng,
    double viewportMaxLng,
  ) =>
      maxLat >= viewportMinLat &&
      minLat <= viewportMaxLat &&
      maxLng >= viewportMinLng &&
      minLng <= viewportMaxLng;

  static Iterable<LatLng> _points(GeoTerrainFeature feature) sync* {
    final geometry = feature.geometry;
    if (geometry != null && geometry.coordinates.isNotEmpty) {
      yield* geometry.coordinates;
    } else {
      yield feature.center;
    }
  }

  static double _minimumLatitude(GeoTerrainFeature feature) => _points(feature)
      .map((point) => point.latitude)
      .reduce((left, right) => left < right ? left : right);

  static double _maximumLatitude(GeoTerrainFeature feature) => _points(feature)
      .map((point) => point.latitude)
      .reduce((left, right) => left > right ? left : right);

  static double _minimumLongitude(GeoTerrainFeature feature) => _points(feature)
      .map((point) => point.longitude)
      .reduce((left, right) => left < right ? left : right);

  static double _maximumLongitude(GeoTerrainFeature feature) => _points(feature)
      .map((point) => point.longitude)
      .reduce((left, right) => left > right ? left : right);
}
