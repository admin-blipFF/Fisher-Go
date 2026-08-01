import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('location integrity migration blocks the legacy session signature', () {
    final migration = File(
      'supabase/migrations/0020_location_integrity_for_fishing_sessions.sql',
    ).readAsStringSync().toLowerCase();

    expect(migration, contains('gameplay_radius_m'));
    expect(migration, contains('location_verified'));
    expect(migration, contains('location_distance_m'));
    expect(migration, contains('p_player_latitude'));
    expect(migration, contains('p_player_longitude'));
    expect(migration, contains('p_accuracy_m'));
    expect(migration, contains('location verification required'));
    expect(migration, contains('player is too far from fishing spot'));
    expect(migration, contains('fishing session start rate limit exceeded'));
    expect(migration, contains('revoke all on function'));
  });

  test('fishing challenge refreshes GPS before a server session starts', () {
    final source = File(
      'lib/features/catches/presentation/catch_log_screen.dart',
    ).readAsStringSync();

    expect(source, contains('_refreshLocationForFishing'));
    expect(source, contains('_locationAccuracyMeters'));
    expect(source, contains('getCurrentPosition'));
    expect(source, contains('accuracyMeters: _locationAccuracyMeters'));
    expect(source, contains('serverSession == null'));
  });
}
