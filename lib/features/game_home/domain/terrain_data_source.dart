import 'dart:convert';
import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

enum TerrainKind { water, shore, land, road, pier, fishingNode }

class TerrainTile {
  const TerrainTile({
    required this.kind,
    required this.row,
    required this.col,
  });

  final TerrainKind kind;
  final int row;
  final int col;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TerrainTile &&
          runtimeType == other.runtimeType &&
          kind == other.kind &&
          row == other.row &&
          col == other.col;

  @override
  int get hashCode => Object.hash(kind, row, col);
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

abstract class TerrainDataSource {
  List<TerrainTile> buildTiles({
    required LatLng playerLatLng,
    required int rows,
    required int cols,
  });

  List<TerrainMapPoint> projectFishingNodes(List<TerrainFishingSpot> spots);
}

class GeoTerrainFeature {
  const GeoTerrainFeature({
    required this.kind,
    required this.name,
    required this.lat,
    required this.lng,
    required this.radiusMeters,
  });

  final TerrainKind kind;
  final String name;
  final double lat;
  final double lng;
  final double radiusMeters;

  LatLng get center => LatLng(lat, lng);
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
}

class GeoTerrainDataSource implements TerrainDataSource {
  const GeoTerrainDataSource(this.dataset);

  final GeoTerrainDataset dataset;
  static const _fallback = LocalTerrainDataSource();
  static const _distance = Distance();

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

    return [
      for (var row = 0; row < rows; row++)
        for (var col = 0; col < cols; col++)
          TerrainTile(
            kind:
                _classifyTile(_tileLatLng(playerLatLng, row, col, rows, cols)),
            row: row,
            col: col,
          ),
    ];
  }

  @override
  List<TerrainMapPoint> projectFishingNodes(List<TerrainFishingSpot> spots) {
    if (spots.isNotEmpty) return _fallback.projectFishingNodes(spots);

    final nodes = dataset.features
        .where((feature) => feature.kind == TerrainKind.fishingNode)
        .take(8)
        .map(
            (feature) => TerrainFishingSpot(lat: feature.lat, lng: feature.lng))
        .toList();
    return _fallback.projectFishingNodes(nodes);
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
    const latSpan = 0.105;
    const lngSpan = 0.135;
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
    for (final feature in dataset.features.where((f) => f.kind == kind)) {
      final distance = _distance.as(LengthUnit.Meter, point, feature.center);
      if (distance <= feature.radiusMeters) {
        final ratio = distance / feature.radiusMeters;
        if (ratio < bestRatio) {
          best = feature;
          bestRatio = ratio;
        }
      }
    }
    return best;
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
}

class LocalTerrainDataSource implements TerrainDataSource {
  const LocalTerrainDataSource();

  static const _fallbackFishingNodes = [
    TerrainMapPoint(0.18, 0.42),
    TerrainMapPoint(0.36, 0.36),
    TerrainMapPoint(0.66, 0.47),
    TerrainMapPoint(0.76, 0.62),
  ];

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
          ),
    ];
  }

  @override
  List<TerrainMapPoint> projectFishingNodes(List<TerrainFishingSpot> spots) {
    if (spots.isEmpty) return _fallbackFishingNodes;
    return spots.take(6).map((spot) {
      final dx = ((spot.lng - 113.8) / (114.55 - 113.8)).clamp(0.12, 0.88);
      final dy = (1 - ((spot.lat - 22.15) / (22.58 - 22.15))).clamp(0.22, 0.82);
      return TerrainMapPoint(dx.toDouble(), dy.toDouble());
    }).toList();
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
}
