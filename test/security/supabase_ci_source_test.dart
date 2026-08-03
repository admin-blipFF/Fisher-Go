import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Supabase RLS tests run in CI', () {
    final sql = File('supabase/tests/player_rls_test.sql').readAsStringSync();
    final workflow =
        File('.github/workflows/supabase-quality.yml').readAsStringSync();

    expect(sql, contains('request.jwt.claim.sub'));
    expect(sql, contains('player_profiles'));
    expect(sql, contains('player_fish_collections'));
    expect(sql, contains('player_catches'));
    expect(workflow, contains('supabase test db'));
    expect(
      workflow,
      contains('supabase db lint --local --schema public --fail-on error'),
    );
  });

  test('RLS pgTAP suite exercises own writes and cross-user mutations', () {
    final sql = File('supabase/tests/player_rls_test.sql')
        .readAsStringSync()
        .toLowerCase();
    final remoteBehavior = File(
      'supabase/tests/remote_player_rls_behavior_test.sql',
    ).readAsStringSync().toLowerCase();

    expect(sql, contains('throws_ok'));
    expect(sql, contains('user a can insert an own profile'));
    expect(sql, contains('user a cannot insert user b profile'));
    expect(sql, contains('user a cannot mutate user b collection'));
    expect(sql, contains('user a cannot delete user b catch'));
    expect(sql, contains('public.catches'));
    expect(sql, contains('user a can insert an own catch record'));
    expect(sql, contains('user a can insert an own profile record'));
    expect(sql, contains('user a cannot insert user b catch record'));
    expect(sql, contains('user a cannot insert user b legacy profile'));
    expect(sql, contains('user a cannot update user b catch record'));
    expect(sql, contains('user a cannot delete user b catch record'));
    expect(sql, contains('user a sees only own legacy profile'));
    expect(remoteBehavior, contains('set_config'));
    expect(remoteBehavior, contains('throws_ok'));
    expect(remoteBehavior, contains('rollback'));
  });

  test('fishing spot moderation is covered by a local pgTAP shape suite', () {
    final sql = File(
      'supabase/tests/fishing_spot_moderation_shape_test.sql',
    ).readAsStringSync().toLowerCase();

    expect(sql, contains('admins read all fishing spots'));
    expect(sql, contains('admins update fishing spots'));
    expect(sql, contains("has_table_privilege('authenticated'"));
    expect(sql, contains('not has_table_privilege'));
    expect(sql, contains('extensions.finish()'));
  });

  test('fishing spot content constraints are covered by local contracts', () {
    final shape = File(
      'supabase/tests/fishing_spot_content_shape_test.sql',
    ).readAsStringSync().toLowerCase();
    final migration = File(
      'supabase/migrations/0024_fishing_spot_content_constraints.sql',
    ).readAsStringSync().toLowerCase();

    expect(shape, contains('habitat tags shape constraint exists'));
    expect(shape, contains('species weights shape constraint exists'));
    expect(shape, contains('content updates remain behind admin rls'));
    expect(shape, contains('finish()'));
    expect(migration, contains('is_valid_fishing_spot_habitat_tags'));
    expect(migration, contains('is_valid_fishing_spot_species_weights'));
  });

  test('catch photo bucket constraints are covered by a local pgTAP shape', () {
    final shape = File(
      'supabase/tests/catch_photo_bucket_shape_test.sql',
    ).readAsStringSync().toLowerCase();
    final migration = File(
      'supabase/migrations/0026_catch_photo_bucket_constraints.sql',
    ).readAsStringSync().toLowerCase();

    expect(shape, contains("id = 'catch-photos'"));
    expect(shape, contains('file_size_limit = 8388608'));
    expect(shape, contains('allowed_mime_types'));
    expect(shape, contains('finish()'));
    expect(shape, contains('begin;'));
    expect(shape, contains('rollback;'));
    expect(shape, contains('public is false'));
    expect(shape, isNot(contains('to anon')));
    expect(migration, contains('update storage.buckets'));
    expect(migration, contains("where id = 'catch-photos'"));
  });

  test('real catch moderation is covered by local pgTAP shape and behavior',
      () {
    final shape = File(
      'supabase/tests/real_catch_moderation_shape_test.sql',
    ).readAsStringSync().toLowerCase();
    final behavior = File(
      'supabase/tests/real_catch_moderation_behavior_test.sql',
    ).readAsStringSync().toLowerCase();

    expect(shape, contains('guard_catch_moderation'));
    expect(shape, contains('admins read catch photos'));
    expect(shape, contains('public leaderboard filters to approved catches'));
    expect(behavior, contains('cannot self-approve'));
    expect(behavior, contains('admin can approve'));
    expect(behavior, contains('suspended real catches leave'));
    expect(behavior, contains('extensions.finish()'));
  });

  test('server-authoritative wallet operations are covered by pgTAP', () {
    final sql = File(
      'supabase/tests/server_authoritative_rewards_shape_test.sql',
    ).readAsStringSync().toLowerCase();

    expect(sql, contains('player_coin_transactions'));
    expect(sql, contains('spend_player_coins(integer,text)'));
    expect(sql, contains('adjust_player_coins(integer,text,text)'));
    expect(sql, contains('claim_my_coin_grants()'));
    expect(sql, contains('security definer'));
    expect(sql, contains('has_function_privilege'));
    expect(sql, contains('extensions.finish()'));
  });

  test('server-authoritative wallet behavior is covered by pgTAP', () {
    final sql = File(
      'supabase/tests/server_authoritative_rewards_behavior_test.sql',
    ).readAsStringSync().toLowerCase();

    expect(sql, contains('spend_player_coins(125'));
    expect(sql, contains('behavior-purchase-1'));
    expect(sql, contains('claim_my_coin_grants()'));
    expect(sql, contains('cannot be claimed twice'));
    expect(sql, contains('extensions.throws_ok'));
    expect(sql, contains('extensions.finish()'));
  });

  test('gameplay reward tickets are covered by a local pgTAP shape suite', () {
    final sql = File(
      'supabase/tests/gameplay_reward_ticket_shape_test.sql',
    ).readAsStringSync().toLowerCase();

    expect(sql, contains('claim_gameplay_reward_ticket'));
    expect(sql, contains('adjust_player_coins'));
    expect(sql, contains('has_function_privilege'));
    expect(sql, contains('extensions.finish()'));
  });

  test('gameplay reward ticket behavior is covered by pgTAP', () {
    final sql = File(
      'supabase/tests/gameplay_reward_ticket_behavior_test.sql',
    ).readAsStringSync().toLowerCase();

    expect(sql, contains('daily task reward is fixed by the server'));
    expect(sql, contains('generic virtual ticket cannot bypass'));
    expect(sql, contains('generic adjust rpc'));
    expect(sql, contains('extensions.throws_ok'));
    expect(sql, contains('extensions.finish()'));
  });

  test('server-validated fishing sessions are covered by pgTAP', () {
    final shape = File(
      'supabase/tests/gameplay_session_shape_test.sql',
    ).readAsStringSync().toLowerCase();
    final behavior = File(
      'supabase/tests/gameplay_session_behavior_test.sql',
    ).readAsStringSync().toLowerCase();

    expect(shape, contains('start_virtual_fishing_session'));
    expect(shape, contains('resolve_virtual_fishing_session'));
    expect(shape, contains('session-bound ticket rpc'));
    expect(behavior, contains('inside the bite window'));
    expect(behavior, contains('early pull is rejected'));
    expect(behavior, contains('extensions.finish()'));

    final location = File(
      'supabase/tests/location_integrity_behavior_test.sql',
    ).readAsStringSync().toLowerCase();
    expect(location, contains('outside the spot radius'));
    expect(location, contains('unusably inaccurate location'));
    expect(location, contains('rate-limits repeated session starts'));
    expect(location, contains('extensions.finish()'));
  });

  test('privacy-safe analytics ingestion is covered by pgTAP', () {
    final shape = File(
      'supabase/tests/analytics_events_shape_test.sql',
    ).readAsStringSync().toLowerCase();
    final behavior = File(
      'supabase/tests/analytics_events_behavior_test.sql',
    ).readAsStringSync().toLowerCase();

    expect(shape, contains('analytics_events'));
    expect(shape, contains('record_analytics_event'));
    expect(shape, contains('not has_table_privilege'));
    expect(shape, contains('extensions.finish()'));
    expect(behavior, contains('sensitive and nested fields'));
    expect(behavior, contains('unknown event names are rejected'));
    expect(behavior, contains('oversized analytics fields are rejected'));
    expect(behavior, contains('extensions.finish()'));
  });

  test('retention reporting is covered by an aggregate-only pgTAP boundary',
      () {
    final shape = File(
      'supabase/tests/analytics_retention_shape_test.sql',
    ).readAsStringSync().toLowerCase();
    final behavior = File(
      'supabase/tests/analytics_retention_behavior_test.sql',
    ).readAsStringSync().toLowerCase();

    expect(shape, contains('analytics_retention_report'));
    expect(shape, contains('day_2_returners'));
    expect(shape, contains('day_7_returners'));
    expect(behavior, contains('non-admins cannot query retention aggregates'));
    expect(behavior, contains('report counts d7 returners'));
    expect(behavior, contains('extensions.finish()'));
  });

  test('event configuration is covered by a server-owned projection', () {
    final shape = File(
      'supabase/tests/server_event_config_shape_test.sql',
    ).readAsStringSync().toLowerCase();
    final behavior = File(
      'supabase/tests/server_event_config_behavior_test.sql',
    ).readAsStringSync().toLowerCase();

    expect(shape, contains('get_active_fishing_event_config'));
    expect(shape, contains('anonymous role cannot read event configuration'));
    expect(behavior, contains('only a boost under an active parent event'));
    expect(behavior, contains('stable fish id'));
    expect(behavior, contains('extensions.finish()'));
  });

  test('notification device tokens are private and RPC-owned', () {
    final shape = File(
      'supabase/tests/notification_device_tokens_shape_test.sql',
    ).readAsStringSync().toLowerCase();
    final behavior = File(
      'supabase/tests/notification_device_tokens_behavior_test.sql',
    ).readAsStringSync().toLowerCase();
    final migration = File(
      'supabase/migrations/0027_notification_device_tokens.sql',
    ).readAsStringSync().toLowerCase();

    expect(migration, contains('player_notification_tokens'));
    expect(migration, contains('security definer'));
    expect(shape, contains('anonymous cannot read notification tokens'));
    expect(shape, contains('anonymous cannot register notification tokens'));
    expect(behavior,
        contains('a different player cannot read another player token'));
    expect(behavior, contains('extensions.finish()'));
    expect(shape, contains('finish()'));
  });
}
