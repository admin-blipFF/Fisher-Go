import 'terrain_data_source.dart';

enum GameRoadLaneMarking { none, dashed, pedestrianHighlight }

class GameRoadStyle {
  const GameRoadStyle({
    required this.casingWidth,
    required this.surfaceWidth,
    required this.laneMarking,
    required this.drawsBridgeDeck,
    required this.drawPriority,
  });

  final double casingWidth;
  final double surfaceWidth;
  final GameRoadLaneMarking laneMarking;
  final bool drawsBridgeDeck;
  final int drawPriority;

  bool get hasVehicleLaneMarkings => laneMarking == GameRoadLaneMarking.dashed;

  bool get hasPedestrianHighlight =>
      laneMarking == GameRoadLaneMarking.pedestrianHighlight;

  GameRoadStyle scaledBy(double factor) {
    final safeFactor = factor.clamp(0.86, 1.12).toDouble();
    return GameRoadStyle(
      casingWidth: casingWidth * safeFactor,
      surfaceWidth: surfaceWidth * safeFactor,
      laneMarking: laneMarking,
      drawsBridgeDeck: drawsBridgeDeck,
      drawPriority: drawPriority,
    );
  }

  factory GameRoadStyle.forFeature(TerrainVectorFeature feature) {
    final roadClass = feature.roadClass;
    final surfaceWidth = switch (roadClass) {
      RoadClass.motorway || RoadClass.trunk => 9.0,
      RoadClass.primary => 7.4,
      RoadClass.secondary => 6.2,
      RoadClass.tertiary => 5.4,
      RoadClass.local => 4.6,
      RoadClass.service => 3.8,
      RoadClass.cycleway => 3.0,
      RoadClass.footway => 2.4,
      RoadClass.unknown => 5.0,
    };
    final laneMarking = switch (roadClass) {
      RoadClass.motorway ||
      RoadClass.trunk ||
      RoadClass.primary ||
      RoadClass.secondary ||
      RoadClass.tertiary =>
        GameRoadLaneMarking.dashed,
      RoadClass.cycleway ||
      RoadClass.footway =>
        GameRoadLaneMarking.pedestrianHighlight,
      RoadClass.local ||
      RoadClass.service ||
      RoadClass.unknown =>
        GameRoadLaneMarking.none,
    };
    final drawPriority = switch (roadClass) {
      RoadClass.footway => 0,
      RoadClass.cycleway => 1,
      RoadClass.service => 2,
      RoadClass.unknown => 3,
      RoadClass.local => 4,
      RoadClass.tertiary => 5,
      RoadClass.secondary => 6,
      RoadClass.primary => 7,
      RoadClass.trunk => 8,
      RoadClass.motorway => 9,
    };

    final casingExtra = switch (roadClass) {
      RoadClass.motorway || RoadClass.trunk => 3.6,
      RoadClass.primary || RoadClass.secondary || RoadClass.tertiary => 3.0,
      RoadClass.local || RoadClass.unknown => 2.2,
      RoadClass.service => 1.8,
      RoadClass.cycleway || RoadClass.footway => 1.4,
    };

    return GameRoadStyle(
      casingWidth: surfaceWidth + casingExtra,
      surfaceWidth: surfaceWidth,
      laneMarking: laneMarking,
      drawsBridgeDeck: feature.isBridge,
      drawPriority: drawPriority,
    );
  }
}
