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

  test('main road widths stay restrained when parallel carriageways overlap',
      () {
    expect(
      GameRoadStyle.forFeature(road(RoadClass.motorway)).surfaceWidth,
      lessThanOrEqualTo(7.8),
    );
    expect(
      GameRoadStyle.forFeature(road(RoadClass.primary)).surfaceWidth,
      lessThanOrEqualTo(6.4),
    );
    expect(
      GameRoadStyle.forFeature(road(RoadClass.secondary)).surfaceWidth,
      lessThanOrEqualTo(5.4),
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

  test('main map roads omit dashed lane markings for clean game readability',
      () {
    expect(
      GameRoadStyle.forFeature(road(RoadClass.primary)).hasVehicleLaneMarkings,
      isFalse,
    );
    expect(
        GameRoadStyle.forFeature(road(RoadClass.primary, isBridge: true))
            .hasVehicleLaneMarkings,
        isFalse);
  });

  test('main map only includes the four highest OSM road classes', () {
    for (final roadClass in const [
      RoadClass.motorway,
      RoadClass.trunk,
      RoadClass.primary,
      RoadClass.secondary,
    ]) {
      expect(GameRoadStyle.isMainRoad(roadClass, ''), isTrue);
    }
    for (final roadClass in const [
      RoadClass.tertiary,
      RoadClass.local,
      RoadClass.service,
      RoadClass.footway,
      RoadClass.cycleway,
      RoadClass.unknown,
    ]) {
      expect(GameRoadStyle.isMainRoad(roadClass, 'Named road'), isFalse);
    }
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

  test('dense road scenes switch to the clean corridor treatment', () {
    expect(
      shouldUseDetailedRoadTreatment(
        budgetAllowsDetails: true,
        visibleRoadCount: 12,
      ),
      isTrue,
    );
    expect(
      shouldUseDetailedRoadTreatment(
        budgetAllowsDetails: true,
        visibleRoadCount: 204,
      ),
      isFalse,
    );
    expect(
      shouldUseDetailedRoadTreatment(
        budgetAllowsDetails: false,
        visibleRoadCount: 4,
      ),
      isFalse,
    );
  });
}
