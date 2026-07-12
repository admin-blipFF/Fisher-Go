import 'package:fishergo/features/game_home/domain/game_road_style.dart';
import 'package:fishergo/features/game_home/domain/terrain_data_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  TerrainVectorFeature road(RoadClass roadClass, {bool isBridge = false}) {
    return TerrainVectorFeature(
      kind: TerrainKind.road,
      name: roadClass.name,
      points: const [LatLng(22.379, 114.191), LatLng(22.38, 114.193)],
      isClosed: false,
      roadClass: roadClass,
      isBridge: isBridge,
    );
  }

  test('road widths establish the major-to-pedestrian visual hierarchy', () {
    expect(
      GameRoadStyle.forFeature(road(RoadClass.primary)).surfaceWidth,
      greaterThan(
          GameRoadStyle.forFeature(road(RoadClass.secondary)).surfaceWidth),
    );
    expect(
      GameRoadStyle.forFeature(road(RoadClass.secondary)).surfaceWidth,
      greaterThan(GameRoadStyle.forFeature(road(RoadClass.local)).surfaceWidth),
    );
    expect(
      GameRoadStyle.forFeature(road(RoadClass.local)).surfaceWidth,
      greaterThan(
          GameRoadStyle.forFeature(road(RoadClass.footway)).surfaceWidth),
    );
  });

  test('footways disable vehicle lane markings', () {
    expect(
      GameRoadStyle.forFeature(road(RoadClass.footway)).hasVehicleLaneMarkings,
      isFalse,
    );
  });

  test('bridge roads enable the elevated deck treatment', () {
    expect(
      GameRoadStyle.forFeature(road(RoadClass.primary, isBridge: true))
          .drawsBridgeDeck,
      isTrue,
    );
  });

  test('depth scaling changes widths while preserving road semantics', () {
    final original =
        GameRoadStyle.forFeature(road(RoadClass.primary, isBridge: true));
    final far = original.scaledBy(0.5);
    final near = original.scaledBy(1.5);

    expect(far.surfaceWidth, closeTo(original.surfaceWidth * 0.86, 0.001));
    expect(near.surfaceWidth, closeTo(original.surfaceWidth * 1.12, 0.001));
    expect(far.casingWidth, lessThan(original.casingWidth));
    expect(near.casingWidth, greaterThan(original.casingWidth));
    expect(far.laneMarking, original.laneMarking);
    expect(far.drawsBridgeDeck, isTrue);
    expect(far.drawPriority, original.drawPriority);
  });
}
