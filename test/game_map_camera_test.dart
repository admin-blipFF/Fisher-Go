import 'dart:ui';

import 'package:fishergo/features/game_home/domain/game_map_camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('GameMapCamera', () {
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
