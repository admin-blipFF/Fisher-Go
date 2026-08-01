import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    'supabase/migrations/0015_gameplay_reward_tickets.sql',
  );

  test('reward-ticket migration defines a server-owned bounded claim boundary',
      () {
    final sql = migration.readAsStringSync().toLowerCase();

    expect(
      sql,
      contains(
          'create table if not exists public.player_gameplay_reward_claims'),
    );
    expect(
      sql,
      contains(
          'create or replace function public.claim_gameplay_reward_ticket'),
    );
    expect(sql, contains('security definer'));
    expect(sql, contains('for update'));
    expect(sql, contains('unique (user_id, reward_kind, claim_key)'));
    expect(sql, contains('virtual_catch'));
    expect(sql, contains('daily_task'));
    expect(sql, contains('case p_reward_kind'));
    expect(sql, contains('rate limit'));
    expect(sql,
        contains('revoke all on table public.player_gameplay_reward_claims'));
    expect(
      sql,
      contains('grant execute on function public.claim_gameplay_reward_ticket'),
    );
    expect(sql, contains('revoke all on function public.adjust_player_coins'));
  });

  test('Flutter reward path calls the ticket RPC before the 0014 fallback', () {
    final source = File(
      'lib/features/profile/data/player_profile_sync_service.dart',
    ).readAsStringSync();

    expect(source, contains("'claim_gameplay_reward_ticket'"));
    expect(source, contains('p_reward_kind'));
    expect(source, contains('p_requested_amount'));
    expect(source, contains('p_claim_key'));
    expect(source, contains('p_fish_id'));
    expect(source, contains('p_gameplay_session_id'));
    expect(source, contains('adjust_player_coins'));
    expect(source, contains('isMissingSupabaseRpc'));
  });

  test('reward callers declare their server reward kind', () {
    final sources = [
      File('lib/features/announcement/presentation/announcement_modal.dart')
          .readAsStringSync(),
      File('lib/features/profile/presentation/profile_screen.dart')
          .readAsStringSync(),
      File('lib/features/game_home/presentation/game_home_screen.dart')
          .readAsStringSync(),
      File('lib/features/catches/presentation/catch_log_screen.dart')
          .readAsStringSync(),
    ].join('\n');

    expect(sources, contains("rewardKind: 'daily_announcement'"));
    expect(sources, contains("rewardKind: 'daily_task_"));
    expect(sources, contains("rewardKind: 'virtual_catch'"));
    expect(sources, contains("rewardKind: 'checkpoint'"));
    expect(sources, contains("rewardKind: 'real_catch'"));
  });
}
