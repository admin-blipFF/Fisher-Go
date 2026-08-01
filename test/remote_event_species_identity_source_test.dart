import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('remote event boosts persist stable fish identity', () {
    final service =
        File('lib/core/admin/admin_ops_service.dart').readAsStringSync();
    final screen = File(
      'lib/features/admin/presentation/admin_screen.dart',
    ).readAsStringSync();
    final migration = File(
      'supabase/migrations/0018_remote_event_fish_identity.sql',
    ).readAsStringSync();

    expect(service, contains("'fish_id': fishId"));
    expect(service, contains("rpc('get_active_fishing_event_config')"));
    expect(service, contains('boosts[fishId]'));
    expect(screen, contains('fishId: _selectedFishId'));
    expect(migration, contains('add column if not exists fish_id text'));
    expect(migration, contains('fish_rate_boosts_fish_id_idx'));
  });

  test('gameplay consumes remote event boosts by stable fish id', () {
    final source = File(
      'lib/features/game_home/presentation/game_home_screen.dart',
    ).readAsStringSync();

    expect(
      source,
      contains(
        'FishingSpawnRules.configuredSpeciesWeight(\n'
        '        weights: widget.fishBoosts,\n'
        '        fishName: fish.name,\n'
        '        fishId: fish.fishId,',
      ),
    );
  });
}
