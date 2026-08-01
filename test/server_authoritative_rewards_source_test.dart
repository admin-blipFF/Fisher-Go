import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    'supabase/migrations/0014_server_authoritative_rewards.sql',
  );

  test('wallet migration exposes atomic server-side operations', () {
    final sql = migration.readAsStringSync().toLowerCase();

    expect(sql,
        contains('create table if not exists public.player_coin_transactions'));
    expect(
        sql, contains('create or replace function public.spend_player_coins'));
    expect(
        sql, contains('create or replace function public.adjust_player_coins'));
    expect(sql,
        contains('create or replace function public.claim_my_coin_grants'));
    expect(sql, contains('security definer'));
    expect(sql, contains('for update'));
    expect(sql, contains('current_balance < p_amount'));
    expect(sql, contains('unique (user_id, idempotency_key)'));
    expect(
        sql, contains('revoke all on table public.player_coin_transactions'));
    expect(
        sql, contains('grant execute on function public.spend_player_coins'));
    expect(
        sql, contains('grant execute on function public.adjust_player_coins'));
    expect(
        sql, contains('grant execute on function public.claim_my_coin_grants'));
    expect(
      sql,
      isNot(contains('grant insert on table public.player_coin_transactions')),
    );
    expect(
      sql,
      isNot(contains('grant update on table public.player_coin_transactions')),
    );
  });

  test(
      'Flutter spending path calls the server RPC before legacy rollout fallback',
      () {
    final source = File(
      'lib/features/profile/data/player_profile_sync_service.dart',
    ).readAsStringSync();

    expect(source, contains(".rpc("));
    expect(source, contains("'spend_player_coins'"));
    expect(source, contains("'adjust_player_coins'"));
    expect(source, contains('p_amount'));
    expect(source, contains('isMissingSupabaseRpc'));
  });

  test('admin grant claim does not credit the wallet a second time on-device',
      () {
    final source =
        File('lib/core/admin/admin_ops_service.dart').readAsStringSync();

    expect(source, contains("rpc('claim_my_coin_grants'"));
    expect(source, contains('ProfileWalletService.getCoins'));
    expect(source, isNot(contains('ProfileWalletService.addCoins')));
  });
}
