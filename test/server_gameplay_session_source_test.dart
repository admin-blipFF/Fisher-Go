import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    'supabase/migrations/0016_server_validated_fishing_sessions.sql',
  );

  test('fishing session migration binds rewards to server timing state', () {
    final sql = migration.readAsStringSync().toLowerCase();

    expect(
      sql,
      contains('create table if not exists public.player_fishing_sessions'),
    );
    expect(sql, contains('start_virtual_fishing_session'));
    expect(sql, contains('resolve_virtual_fishing_session'));
    expect(sql, contains('bite_at'));
    expect(sql, contains('success_window_ends_at'));
    expect(sql, contains('resolved_success'));
    expect(sql, contains('for update'));
    expect(sql, contains('claimed_at'));
    expect(sql, contains('p_gameplay_session_id'));
    expect(sql, contains('virtual fishing session required'));
    expect(sql, contains('grant execute'));
    expect(sql, contains('revoke all on table public.player_fishing_sessions'));
  });

  test('Flutter fishing flow starts and resolves a server session', () {
    final source = File(
      'lib/features/catches/data/virtual_fishing_session_service.dart',
    ).readAsStringSync();

    expect(source, contains("'start_virtual_fishing_session'"));
    expect(source, contains("'resolve_virtual_fishing_session'"));
    expect(source, contains('p_spot_id'));
    expect(source, contains('p_lure_id'));
    expect(source, contains('p_fish_id'));
    expect(source, contains('p_player_latitude'));
    expect(source, contains('p_player_longitude'));
    expect(source, contains('p_accuracy_m'));
    expect(source, contains('p_session_id'));
    expect(source, contains('p_pull_elapsed_ms'));
    expect(source, contains('isMissingSupabaseRpc'));
  });

  test('minigame passes the server session through the reward boundary', () {
    final source = File(
      'lib/features/catches/presentation/catch_log_screen.dart',
    ).readAsStringSync();

    expect(source, contains('VirtualFishingSessionService.start'));
    expect(source, contains('VirtualFishingSessionService.resolve'));
    expect(source, contains('gameplaySessionId'));
    expect(source, contains('pullElapsedMs'));
  });
}
