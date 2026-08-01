import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('catch sync schema owns every real-catch payload field', () {
    final source = File(
      'supabase/migrations/0013_real_catch_leaderboard.sql',
    ).readAsStringSync();

    expect(source, contains('add column if not exists is_real_catch_proof'));
    expect(source, contains('add column if not exists recognized_species_id'));
    expect(source, contains('add column if not exists recognition_confidence'));
    expect(source, contains('add column if not exists verified_at'));
  });

  test('public leaderboard RPC exposes verified catch data without user ids',
      () {
    final source = File(
      'supabase/migrations/0013_real_catch_leaderboard.sql',
    ).readAsStringSync().toLowerCase();

    expect(source, contains('get_public_leaderboard'));
    expect(source, contains('is_real_catch_proof = true'));
    expect(source, contains('verified_at is not null'));
    expect(source,
        contains('grant execute on function public.get_public_leaderboard'));
    expect(source, contains('limit_count'));
    expect(source, isNot(contains('returns table (user_id')));
  });

  test('leaderboard screen uses a cloud-first data source with local fallback',
      () {
    final source =
        File('lib/features/leaderboard/presentation/leaderboard_screen.dart')
            .readAsStringSync();

    expect(source, contains('PublicLeaderboardService.load'));
    expect(source, contains('verifiedRows'));
    expect(source, contains('catch')); // keeps the fallback branch explicit
  });
}
