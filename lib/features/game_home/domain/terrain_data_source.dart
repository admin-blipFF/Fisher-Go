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
