import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('UUID player ownership migration fails closed and cascades Auth data',
      () {
    final migration = File(
      'supabase/migrations/0028_uuid_player_ownership.sql',
    ).readAsStringSync().toLowerCase();
    final shape = File(
      'supabase/tests/player_uuid_ownership_shape_test.sql',
    ).readAsStringSync().toLowerCase();
    final behavior = File(
      'supabase/tests/player_uuid_ownership_behavior_test.sql',
    ).readAsStringSync().toLowerCase();
    final workflow = File(
      '.github/workflows/supabase-content-release.yml',
    ).readAsStringSync();

    expect(migration, contains('malformed auth uuid exists'));
    expect(migration, contains('orphaned auth uuid exists'));
    expect(migration, contains('on delete cascade'));
    expect(migration, contains('actor_id uuid;'));
    expect(migration, contains('auth.uid() = user_id'));
    expect(migration, isNot(contains('drop table')));
    for (final table in [
      'player_profiles',
      'player_fish_collections',
      'player_catches',
      'player_coin_transactions',
      'player_gameplay_reward_claims',
      'player_fishing_sessions',
    ]) {
      expect(migration, contains(table));
    }
    expect(shape, contains('all player-owned user_id columns are uuids'));
    expect(behavior, contains('deleted with its auth user'));
    expect(behavior, contains('another user remains isolated'));
    expect(
      workflow,
      contains('supabase/tests/player_uuid_ownership_shape_test.sql'),
    );
  });
}
