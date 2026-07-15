import 'dart:ui';

import 'package:fishergo/features/game_home/domain/game_map_camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test('grid layout follows portrait and landscape viewport proportions', () {
    final portrait = GameMapGridLayout.forViewport(const Size(390, 844));
    final landscape = GameMapGridLayout.forViewport(const Size(1280, 720));

    expect(portrait.rows, 29);
    expect(portrait.cols, 14);
    expect(landscape.rows, 29);
    expect(landscape.cols, 51);
  });

  group('GameMapCamera', () {
    test('supports a lower gameplay anchor without changing GPS center', () {
      final camera = GameMapCamera(
        center: const LatLng(22.35, 114.07),
        visibleRadiusMeters: 500,
        bearingDegrees: 0,
        viewportSize: const Size(390, 844),
        viewportAnchorY: 0.56,
      );

      expect(camera.viewportCenter.dx, 195);
      expect(camera.viewportCenter.dy, closeTo(472.64, 0.0001));
      expect(camera.project(camera.center), camera.viewportCenter);
    });

    test('ground perspective compresses far features and enlarges near ones',
        () {
      final flat = GameMapCamera(
        center: const LatLng(22.35, 114.07),
        visibleRadiusMeters: 500,
        bearingDegrees: 0,
        viewportSize: const Size(390, 844),
      );
      final perspective = GameMapCamera(
        center: const LatLng(22.35, 114.07),
        visibleRadiusMeters: 500,
        bearingDegrees: 0,
        viewportSize: const Size(390, 844),
        perspectiveStrength: 0.3,
      );
      const north = LatLng(22.353, 114.07);
      const south = LatLng(22.347, 114.07);

      expect(
        (perspective.project(north) - perspective.viewportCenter).distance,
        lessThan((flat.project(north) - flat.viewportCenter).distance),
      );
      expect(
        (perspective.project(south) - perspective.viewportCenter).distance,
        greaterThan((flat.project(south) - flat.viewportCenter).distance),
      );
      expect(perspective.depthScaleFor(north), lessThan(1));
      expect(perspective.depthScaleFor(south), greaterThan(1));
    });

    test('perspective depth follows bearing rotation', () {
      final camera = GameMapCamera(
        center: const LatLng(22.35, 114.07),
        visibleRadiusMeters: 500,
        bearingDegrees: 90,
        viewportSize: const Size(390, 844),
        perspectiveStrength: 0.3,
      );
      const east = LatLng(22.35, 114.073);
      const west = LatLng(22.35, 114.067);

      expect(camera.depthScaleFor(east), greaterThan(1));
      expect(camera.depthScaleFor(west), lessThan(1));
    });

    test('tilted gameplay projection creates a near, middle, and far plane',
        () {
      final camera = GameMapCamera(
        center: const LatLng(22.35, 114.07),
        visibleRadiusMeters: 500,
        bearingDegrees: 0,
        viewportSize: const Size(390, 844),
        perspectiveStrength: 0.52,
        viewportAnchorY: 0.68,
      );
      const farNorth = LatLng(22.35449, 114.07);
      const nearSouth = LatLng(22.34730, 114.07);

      expect(camera.project(farNorth).dy, lessThan(844 * 0.28));
      expect(camera.project(nearSouth).dy, greaterThan(844 * 0.9));
      expect(camera.project(camera.center).dy, closeTo(844 * 0.68, 0.001));
    });

    test('projects center GPS to viewport center', () {
      final camera = GameMapCamera(
        center: const LatLng(22.3517, 114.0743),
        visibleRadiusMeters: 500,
        bearingDegrees: 0,
        viewportSize: const Size(390, 844),
      );

      final projected = camera.project(const LatLng(22.3517, 114.0743));

      expect(projected.dx, closeTo(195, 0.01));
      expect(projected.dy, closeTo(422, 0.01));
    });

    test('projects north point above center with zero bearing', () {
      final camera = GameMapCamera(
        center: const LatLng(22.3517, 114.0743),
        visibleRadiusMeters: 500,
        bearingDegrees: 0,
        viewportSize: const Size(390, 844),
      );

      final projected = camera.project(const LatLng(22.3562, 114.0743));

      expect(projected.dx, closeTo(195, 1));
      expect(projected.dy, lessThan(422));
    });

    test('projects east point right of center with zero bearing', () {
      final camera = GameMapCamera(
        center: const LatLng(22.3517, 114.0743),
        visibleRadiusMeters: 500,
        bearingDegrees: 0,
        viewportSize: const Size(390, 844),
      );

      final projected = camera.project(const LatLng(22.3517, 114.0792));

      expect(projected.dx, greaterThan(195));
      expect(projected.dy, closeTo(422, 1));
    });

    test('bearing rotates projected points around center', () {
      final camera = GameMapCamera(
        center: const LatLng(22.3517, 114.0743),
        visibleRadiusMeters: 500,
        bearingDegrees: 90,
        viewportSize: const Size(390, 844),
      );

      final projected = camera.project(const LatLng(22.3562, 114.0743));

      expect(projected.dx, greaterThan(195));
      expect(projected.dy, closeTo(422, 8));
    });

    test('isVisible includes far north point inside tall viewport', () {
      final camera = GameMapCamera(
        center: const LatLng(22.3517, 114.0743),
        visibleRadiusMeters: 500,
        bearingDegrees: 0,
        viewportSize: const Size(390, 844),
      );

      expect(camera.isVisible(const LatLng(22.3598, 114.0743)), isTrue);
    });

    test('isVisible excludes point well outside viewport', () {
      final camera = GameMapCamera(
        center: const LatLng(22.3517, 114.0743),
        visibleRadiusMeters: 500,
        bearingDegrees: 0,
        viewportSize: const Size(390, 844),
      );

      expect(camera.isVisible(const LatLng(22.3517, 114.0940)), isFalse);
    });

    test('bearing 360 projects the same as bearing 0', () {
      final zeroBearingCamera = GameMapCamera(
        center: const LatLng(22.3517, 114.0743),
        visibleRadiusMeters: 500,
        bearingDegrees: 0,
        viewportSize: const Size(390, 844),
      );
      final fullTurnCamera = GameMapCamera(
        center: const LatLng(22.3517, 114.0743),
        visibleRadiusMeters: 500,
        bearingDegrees: 360,
        viewportSize: const Size(390, 844),
      );

      final zeroBearing = zeroBearingCamera.project(
        const LatLng(22.3562, 114.0792),
      );
      final fullTurn = fullTurnCamera.project(
        const LatLng(22.3562, 114.0792),
      );

      expect(fullTurn.dx, closeTo(zeroBearing.dx, 0.01));
      expect(fullTurn.dy, closeTo(zeroBearing.dy, 0.01));
    });
  });
}
