import 'dart:convert';
import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

enum TerrainKind { water, shore, land, road, pier, fishingNode }

enum RoadClass {
  motorway,
  trunk,
  primary,
  secondary,
  tertiary,
  local,
  service,
  footway,
  cycleway,
  unknown,
}

bool terrainPolygonContains(LatLng point, List<LatLng> polygon) {
  if (polygon.length < 3) return false;
  var inside = false;
  for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    final xi = polygon[i].longitude;
    final yi = polygon[i].latitude;
    final xj = polygon[j].longitude;
    final yj = polygon[j].latitude;
    final intersects = ((yi > point.latitude) != (yj > point.latitude)) &&
        (point.longitude < (xj - xi) * (point.latitude - yi) / (yj - yi) + xi);
    if (intersects) inside = !inside;
  }
  return inside;
}

class TerrainTile {
  const TerrainTile({
    required this.kind,
    required this.row,
    required this.col,
    required this.centerLatLng,
  });

  final TerrainKind kind;
  final int row;
  final int col;
  final LatLng centerLatLng;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TerrainTile &&
          runtimeType == other.runtimeType &&
          kind == other.kind &&
          row == other.row &&
          col == other.col &&
          centerLatLng == other.centerLatLng;

  @override
  int get hashCode => Object.hash(kind, row, col, centerLatLng);
}

class TerrainFishingSpot {
  const TerrainFishingSpot({required this.lat, required this.lng});

  final double lat;
  final double lng;
}

class TerrainMapPoint {
  const TerrainMapPoint(this.dx, this.dy);

  final double dx;
  final double dy;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TerrainMapPoint &&
          runtimeType == other.runtimeType &&
          dx == other.dx &&
          dy == other.dy;

  @override
  int get hashCode => Object.hash(dx, dy);
}

class TerrainVectorFeature {
  const TerrainVectorFeature({
    required this.kind,
    required this.name,
    required this.points,
    required this.isClosed,
    this.roadClass = RoadClass.unknown,
    this.isBridge = false,
    this.lanes,
  });

  final TerrainKind kind;
  final String name;
  final List<LatLng> points;
  final bool isClosed;
  final RoadClass roadClass;
  final bool isBridge;
  final int? lanes;
}

abstract class TerrainDataSource {
  List<TerrainTile> buildTiles({
    required LatLng playerLatLng,
    required int rows,
    required int cols,
  });

  List<TerrainMapPoint> projectFishingNodes(List<TerrainFishingSpot> spots);

  List<TerrainVectorFeature> visibleVectorFeatures({
    required LatLng playerLatLng,
    required double radiusMeters,
  });
}

class GeoTerrainFeature {
  const GeoTerrainFeature({
    required this.kind,
    required this.name,
    required this.lat,
    required this.lng,
    required this.radiusMeters,
    this.geometry,
    this.roadClass = RoadClass.unknown,
    this.isBridge = false,
    this.lanes,
  });

  final TerrainKind kind;
  final String name;
  final double lat;
  final double lng;
  final double radiusMeters;
  final GeoTerrainGeometry? geometry;
  final RoadClass roadClass;
  final bool isBridge;
  final int? lanes;

  LatLng get center => LatLng(lat, lng);
}

class GeoTerrainGeometry {
  const GeoTerrainGeometry({
    required this.type,
    required this.coordinates,
  });

  final String type;
  final List<LatLng> coordinates;

  bool get isPolygon => type == 'polygon';
  bool get isLineString => type == 'lineString';

  factory GeoTerrainGeometry.fromJson(Map<String, dynamic> source) {
    final coordinatesJson = source['coordinates'] as List<dynamic>? ?? const [];
    return GeoTerrainGeometry(
      type: source['type'] as String,
      coordinates: [
        for (final coordinate in coordinatesJson)
          LatLng(
            ((coordinate as List<dynamic>)[0] as num).toDouble(),
            (coordinate[1] as num).toDouble(),
          ),
      ],
    );
  }
}

class GeoTerrainDataset {
  const GeoTerrainDataset({required this.features});

  final List<GeoTerrainFeature> features;

  factory GeoTerrainDataset.fromJson(String source) {
    final decoded = jsonDecode(source) as Map<String, dynamic>;
    final featuresJson = decoded['features'] as List<dynamic>? ?? const [];
    return GeoTerrainDataset(
      features: [
        for (final raw in featuresJson)
          GeoTerrainFeature(
            kind: _parseKind((raw as Map<String, dynamic>)['kind'] as String),
            name: raw['name'] as String,
            lat: (raw['lat'] as num).toDouble(),
            lng: (raw['lng'] as num).toDouble(),
            radiusMeters: (raw['radiusMeters'] as num).toDouble(),
            roadClass: _parseRoadClass(raw['roadClass'] as String?),
            isBridge: raw['isBridge'] as bool? ?? false,
            lanes: (raw['lanes'] as num?)?.toInt(),
            geometry: raw['geometry'] is Map<String, dynamic>
                ? GeoTerrainGeometry.fromJson(
                    raw['geometry'] as Map<String, dynamic>,
                  )
                : null,
          ),
      ],
    );
  }

  static TerrainKind _parseKind(String value) {
    for (final kind in TerrainKind.values) {
      if (kind.name == value) return kind;
    }
    throw FormatException('Unknown terrain kind: $value');
  }

  static RoadClass _parseRoadClass(String? value) {
    for (final roadClass in RoadClass.values) {
      if (roadClass.name == value) return roadClass;
    }
    return RoadClass.unknown;
  }
}

class GeoTerrainDataSource implements TerrainDataSource {
  GeoTerrainDataSource(this.dataset)
      : _indexedFeaturesByKind = {
          for (final kind in TerrainKind.values)
            kind: [
              for (final feature in dataset.features)
                if (feature.kind == kind) _GeoIndexedFeature(feature),
            ],
        };

  final GeoTerrainDataset dataset;
  final Map<TerrainKind, List<_GeoIndexedFeature>> _indexedFeaturesByKind;
  static const _fallback = LocalTerrainDataSource();
  static const _distance = Distance();
  LatLng? _cachedTileCenter;
  int? _cachedTileRows;
  int? _cachedTileCols;
  List<TerrainTile>? _cachedTiles;

  @override
  List<TerrainTile> buildTiles({
    required LatLng playerLatLng,
    required int rows,
    required int cols,
  }) {
    if (dataset.features.isEmpty) {
      return _fallback.buildTiles(
        playerLatLng: playerLatLng,
        rows: rows,
        cols: cols,
      );
    }

    if (_cachedTileCenter == playerLatLng &&
        _cachedTileRows == rows &&
        _cachedTileCols == cols) {
      return _cachedTiles!;
    }

    final tiles = [
      for (var row = 0; row < rows; row++)
        for (var col = 0; col < cols; col++)
          TerrainTile(
            kind:
                _classifyTile(_tileLatLng(playerLatLng, row, col, rows, cols)),
            row: row,
            col: col,
            centerLatLng: _tileLatLng(playerLatLng, row, col, rows, cols),
          ),
    ];
    _cachedTileCenter = playerLatLng;
    _cachedTileRows = rows;
    _cachedTileCols = cols;
    return _cachedTiles = List.unmodifiable(tiles);
  }

  @override
  List<TerrainMapPoint> projectFishingNodes(List<TerrainFishingSpot> spots) {
    if (spots.isEmpty) return const [];
    return _fallback.projectFishingNodes(spots);
  }

  @override
  List<TerrainVectorFeature> visibleVectorFeatures({
    required LatLng playerLatLng,
    required double radiusMeters,
  }) {
    return [
      for (final feature in dataset.features)
        if (_isVisibleVectorFeature(playerLatLng, radiusMeters, feature))
          TerrainVectorFeature(
            kind: feature.kind,
            name: feature.name,
            points: feature.geometry!.coordinates,
            isClosed: feature.geometry!.isPolygon,
            roadClass: feature.roadClass,
            isBridge: feature.isBridge,
            lanes: feature.lanes,
          ),
    ];
  }

  LatLng _tileLatLng(
    LatLng playerLatLng,
    int row,
    int col,
    int rows,
    int cols,
  ) {
    final rowT = rows <= 1 ? 0.5 : row / (rows - 1);
    final colT = cols <= 1 ? 0.5 : col / (cols - 1);
    const latSpan = 0.009;
    final verticalIntervals = math.max(1, rows - 1);
    final horizontalIntervals = math.max(1, cols - 1);
    final metersPerDegreeLng =
        111320.0 * math.cos(playerLatLng.latitude * math.pi / 180);
    final latitudeSpanMeters = latSpan * 111320.0;
    final longitudeSpanMeters =
        latitudeSpanMeters * horizontalIntervals / verticalIntervals;
    final lngSpan = longitudeSpanMeters / metersPerDegreeLng;
    return LatLng(
      playerLatLng.latitude + (0.5 - rowT) * latSpan,
      playerLatLng.longitude + (colT - 0.5) * lngSpan,
    );
  }

  TerrainKind _classifyTile(LatLng point) {
    final fishingNode = _firstContaining(point, TerrainKind.fishingNode);
    if (fishingNode != null) return TerrainKind.fishingNode;

    final pier = _firstContaining(point, TerrainKind.pier);
    if (pier != null) return TerrainKind.pier;

    final road = _firstContaining(point, TerrainKind.road);
    if (road != null) return TerrainKind.road;

    final land = _firstContaining(point, TerrainKind.land);
    final water = _firstContaining(point, TerrainKind.water);
    if (land != null && water != null) {
      final landDistance = _distance.as(LengthUnit.Meter, point, land.center);
      final waterDistance = _distance.as(LengthUnit.Meter, point, water.center);
      if ((land.radiusMeters - landDistance).abs() < 450 ||
          (water.radiusMeters - waterDistance).abs() < 450) {
        return TerrainKind.shore;
      }
      return landDistance / land.radiusMeters <=
              waterDistance / water.radiusMeters
          ? TerrainKind.land
          : TerrainKind.water;
    }

    if (land != null) return TerrainKind.land;
    if (water != null) return TerrainKind.water;

    final nearWater = _nearestOfKind(point, TerrainKind.water);
    if (nearWater != null) {
      final distance = _distance.as(LengthUnit.Meter, point, nearWater.center);
      if (distance <= nearWater.radiusMeters + 650) return TerrainKind.shore;
    }

    return TerrainKind.land;
  }

  GeoTerrainFeature? _firstContaining(LatLng point, TerrainKind kind) {
    GeoTerrainFeature? best;
    double bestRatio = double.infinity;
    for (final indexed in _candidateFeatures(point, kind)) {
      final feature = indexed.feature;
      final distance = _featureDistanceMeters(point, feature);
      final radius = _effectiveRadiusMeters(feature);
      if (distance <= radius || _containsGeometry(point, feature)) {
        final ratio = distance / radius;
        if (ratio < bestRatio) {
          best = feature;
          bestRatio = ratio;
        }
      }
    }
    return best;
  }

  int candidateFeatureCount(LatLng point, TerrainKind kind) =>
      _candidateFeatures(point, kind).length;

  List<_GeoIndexedFeature> _candidateFeatures(
    LatLng point,
    TerrainKind kind,
  ) =>
      [
        for (final indexed in _indexedFeaturesByKind[kind] ?? const [])
          if (indexed.contains(point)) indexed,
      ];

  bool _isVisibleVectorFeature(
    LatLng playerLatLng,
    double radiusMeters,
    GeoTerrainFeature feature,
  ) {
    final geometry = feature.geometry;
    if (geometry == null || geometry.coordinates.length < 2) return false;
    if (feature.kind == TerrainKind.fishingNode) return false;
    if (_featureDistanceMeters(playerLatLng, feature) <= radiusMeters) {
      return true;
    }
    return geometry.coordinates.any(
      (point) =>
          _distance.as(LengthUnit.Meter, playerLatLng, point) <= radiusMeters,
    );
  }

  double _effectiveRadiusMeters(GeoTerrainFeature feature) {
    if (feature.geometry != null) {
      return switch (feature.kind) {
        TerrainKind.road => math.min(feature.radiusMeters, 160),
        TerrainKind.pier => math.min(feature.radiusMeters, 90),
        TerrainKind.fishingNode => math.min(feature.radiusMeters, 95),
        _ => feature.radiusMeters,
      };
    }
    return switch (feature.kind) {
      TerrainKind.road => math.min(feature.radiusMeters, 160),
      TerrainKind.pier => math.min(feature.radiusMeters, 90),
      TerrainKind.fishingNode => math.min(feature.radiusMeters, 95),
      _ => feature.radiusMeters,
    };
  }

  GeoTerrainFeature? _nearestOfKind(LatLng point, TerrainKind kind) {
    GeoTerrainFeature? best;
    double bestDistance = double.infinity;
    for (final feature in dataset.features.where((f) => f.kind == kind)) {
      final distance = _distance.as(LengthUnit.Meter, point, feature.center);
      if (distance < bestDistance) {
        best = feature;
        bestDistance = distance;
      }
    }
    return best;
  }

  double _featureDistanceMeters(LatLng point, GeoTerrainFeature feature) {
    final geometry = feature.geometry;
    if (geometry != null && geometry.isLineString) {
      return _distanceToLineStringMeters(point, geometry.coordinates);
    }
    if (geometry != null &&
        geometry.isPolygon &&
        _pointInPolygon(point, geometry.coordinates)) {
      return 0;
    }
    return _distance.as(LengthUnit.Meter, point, feature.center);
  }

  bool _containsGeometry(LatLng point, GeoTerrainFeature feature) {
    final geometry = feature.geometry;
    return geometry != null &&
        geometry.isPolygon &&
        _pointInPolygon(point, geometry.coordinates);
  }

  double _distanceToLineStringMeters(LatLng point, List<LatLng> line) {
    if (line.length < 2) return double.infinity;
    var best = double.infinity;
    for (var i = 0; i < line.length - 1; i++) {
      best =
          math.min(best, _distanceToSegmentMeters(point, line[i], line[i + 1]));
    }
    return best;
  }

  double _distanceToSegmentMeters(LatLng point, LatLng a, LatLng b) {
    const metersPerDegreeLat = 111320.0;
    final metersPerDegreeLng =
        111320.0 * math.cos(point.latitude * math.pi / 180);
    final px = point.longitude * metersPerDegreeLng;
    final py = point.latitude * metersPerDegreeLat;
    final ax = a.longitude * metersPerDegreeLng;
    final ay = a.latitude * metersPerDegreeLat;
    final bx = b.longitude * metersPerDegreeLng;
    final by = b.latitude * metersPerDegreeLat;
    final dx = bx - ax;
    final dy = by - ay;
    final lengthSquared = dx * dx + dy * dy;
    if (lengthSquared == 0) {
      return math.sqrt(math.pow(px - ax, 2) + math.pow(py - ay, 2));
    }
    final t = (((px - ax) * dx + (py - ay) * dy) / lengthSquared).clamp(0, 1);
    final cx = ax + dx * t;
    final cy = ay + dy * t;
    return math.sqrt(math.pow(px - cx, 2) + math.pow(py - cy, 2));
  }

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

class _GeoIndexedFeature {
  _GeoIndexedFeature(this.feature)
      : minLat = _minimumLatitude(feature) - _latitudePadding(feature),
        maxLat = _maximumLatitude(feature) + _latitudePadding(feature),
        minLng = _minimumLongitude(feature) - _longitudePadding(feature),
        maxLng = _maximumLongitude(feature) + _longitudePadding(feature);

  final GeoTerrainFeature feature;
  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;

  bool contains(LatLng point) =>
      point.latitude >= minLat &&
      point.latitude <= maxLat &&
      point.longitude >= minLng &&
      point.longitude <= maxLng;

  static Iterable<LatLng> _points(GeoTerrainFeature feature) sync* {
    final geometry = feature.geometry;
    if (geometry != null && geometry.coordinates.isNotEmpty) {
      yield* geometry.coordinates;
    } else {
      yield feature.center;
    }
  }

  static double _effectiveRadius(GeoTerrainFeature feature) =>
      switch (feature.kind) {
        TerrainKind.road => math.min(feature.radiusMeters, 160),
        TerrainKind.pier => math.min(feature.radiusMeters, 90),
        TerrainKind.fishingNode => math.min(feature.radiusMeters, 95),
        _ => feature.geometry == null ? feature.radiusMeters : 20,
      };

  static double _latitudePadding(GeoTerrainFeature feature) =>
      _effectiveRadius(feature) / 111320;

  static double _longitudePadding(GeoTerrainFeature feature) =>
      _effectiveRadius(feature) / 100000;

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

class LocalTerrainDataSource implements TerrainDataSource {
  const LocalTerrainDataSource();

  @override
  List<TerrainTile> buildTiles({
    required LatLng playerLatLng,
    required int rows,
    required int cols,
  }) {
    final seed = playerLatLng.latitude * 0.37 + playerLatLng.longitude * 0.19;
    return [
      for (var row = 0; row < rows; row++)
        for (var col = 0; col < cols; col++)
          TerrainTile(
            kind: _classifyTerrain(row, col, rows, cols, seed),
            row: row,
            col: col,
            centerLatLng: _tileLatLng(playerLatLng, row, col, rows, cols),
          ),
    ];
  }

  @override
  List<TerrainMapPoint> projectFishingNodes(List<TerrainFishingSpot> spots) {
    if (spots.isEmpty) return const [];
    return spots.take(6).map((spot) {
      final dx = ((spot.lng - 113.8) / (114.55 - 113.8)).clamp(0.12, 0.88);
      final dy = (1 - ((spot.lat - 22.15) / (22.58 - 22.15))).clamp(0.22, 0.82);
      return TerrainMapPoint(dx.toDouble(), dy.toDouble());
    }).toList();
  }

  @override
  List<TerrainVectorFeature> visibleVectorFeatures({
    required LatLng playerLatLng,
    required double radiusMeters,
  }) {
    return const [];
  }

  TerrainKind _classifyTerrain(
    int row,
    int col,
    int rows,
    int cols,
    double seed,
  ) {
    final coastLine = 3.2 + math.sin((col + seed) * 0.8) * 1.15;
    final roadCenter = cols * 0.72 + math.sin((row + seed) * 0.55) * 1.25;
    final leftPier = row >= 5 && row <= 7 && col == 1;
    final lowerPier = row >= 10 && row <= 12 && col == 7;
    final fishingNode = (row == 5 && col == 3) ||
        (row == 7 && col == 6) ||
        (row == 10 && col == 2);

    if (leftPier || lowerPier) return TerrainKind.pier;
    if (fishingNode) return TerrainKind.fishingNode;
    if ((col - roadCenter).abs() < 0.7 && row > 2) return TerrainKind.road;
    if (row < coastLine) return TerrainKind.water;
    if ((row - coastLine).abs() < 1.1) return TerrainKind.shore;
    return TerrainKind.land;
  }

  LatLng _tileLatLng(
    LatLng playerLatLng,
    int row,
    int col,
    int rows,
    int cols,
  ) {
    final rowT = rows <= 1 ? 0.5 : row / (rows - 1);
    final colT = cols <= 1 ? 0.5 : col / (cols - 1);
    const latSpan = 0.009;
    final verticalIntervals = math.max(1, rows - 1);
    final horizontalIntervals = math.max(1, cols - 1);
    final metersPerDegreeLng =
        111320.0 * math.cos(playerLatLng.latitude * math.pi / 180);
    final latitudeSpanMeters = latSpan * 111320.0;
    final longitudeSpanMeters =
        latitudeSpanMeters * horizontalIntervals / verticalIntervals;
    final lngSpan = longitudeSpanMeters / metersPerDegreeLng;
    return LatLng(
      playerLatLng.latitude + (0.5 - rowT) * latSpan,
      playerLatLng.longitude + (colT - 0.5) * lngSpan,
    );
  }
}
