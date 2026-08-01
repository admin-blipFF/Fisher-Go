import 'package:geolocator/geolocator.dart';

enum LocationAccessState {
  ready,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
}

/// Small platform boundary so permission behavior can be tested without
/// showing a real Android system prompt.
abstract interface class LocationPlatform {
  Future<bool> isLocationServiceEnabled();

  Future<LocationPermission> checkPermission();

  Future<LocationPermission> requestPermission();
}

class GeolocatorLocationPlatform implements LocationPlatform {
  const GeolocatorLocationPlatform();

  @override
  Future<bool> isLocationServiceEnabled() {
    return Geolocator.isLocationServiceEnabled();
  }

  @override
  Future<LocationPermission> checkPermission() {
    return Geolocator.checkPermission();
  }

  @override
  Future<LocationPermission> requestPermission() {
    return Geolocator.requestPermission();
  }
}

class LocationAccessService {
  const LocationAccessService({LocationPlatform? platform})
      : platform = platform ?? const GeolocatorLocationPlatform();

  final LocationPlatform platform;

  Future<LocationAccessState> ensureReady() async {
    if (!await platform.isLocationServiceEnabled()) {
      return LocationAccessState.serviceDisabled;
    }

    var permission = await platform.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await platform.requestPermission();
    }

    return switch (permission) {
      LocationPermission.always ||
      LocationPermission.whileInUse =>
        LocationAccessState.ready,
      LocationPermission.deniedForever =>
        LocationAccessState.permissionDeniedForever,
      LocationPermission.denied ||
      LocationPermission.unableToDetermine =>
        LocationAccessState.permissionDenied,
    };
  }
}
