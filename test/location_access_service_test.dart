import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

import 'package:fishergo/core/location/location_access_service.dart';

void main() {
  test('returns serviceDisabled without requesting permission', () async {
    final platform = _FakeLocationPlatform(
      serviceEnabled: false,
      permission: LocationPermission.denied,
    );

    final result =
        await LocationAccessService(platform: platform).ensureReady();

    expect(result, LocationAccessState.serviceDisabled);
    expect(platform.requestCount, 0);
  });

  test('requests denied permission and becomes ready when granted', () async {
    final platform = _FakeLocationPlatform(
      serviceEnabled: true,
      permission: LocationPermission.denied,
      requestedPermission: LocationPermission.whileInUse,
    );

    final result =
        await LocationAccessService(platform: platform).ensureReady();

    expect(result, LocationAccessState.ready);
    expect(platform.requestCount, 1);
  });

  test('preserves deniedForever without repeating the system prompt', () async {
    final platform = _FakeLocationPlatform(
      serviceEnabled: true,
      permission: LocationPermission.deniedForever,
    );

    final result =
        await LocationAccessService(platform: platform).ensureReady();

    expect(result, LocationAccessState.permissionDeniedForever);
    expect(platform.requestCount, 0);
  });
}

class _FakeLocationPlatform implements LocationPlatform {
  _FakeLocationPlatform({
    required this.serviceEnabled,
    required this.permission,
    this.requestedPermission,
  });

  final bool serviceEnabled;
  final LocationPermission permission;
  final LocationPermission? requestedPermission;
  int requestCount = 0;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async {
    requestCount++;
    return requestedPermission ?? permission;
  }
}
