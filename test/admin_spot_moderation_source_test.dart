import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('admin operations expose a fishing-spot moderation boundary', () {
    final source =
        File('lib/core/admin/admin_ops_service.dart').readAsStringSync();

    expect(source, contains('loadFishingSpotsForModeration'));
    expect(source, contains('moderateFishingSpot'));
    expect(source, contains("from('fishing_spots')"));
    expect(source, contains("verification_status"));
  });

  test('admin screen exposes fishing-spot moderation controls', () {
    final source = File('lib/features/admin/presentation/admin_screen.dart')
        .readAsStringSync();

    expect(source, contains('釣點審核與停用'));
    expect(source, contains('loadFishingSpotsForModeration'));
    expect(source, contains('moderateFishingSpot'));
  });

  test('fishing-spot moderation migration grants update only behind admin RLS',
      () {
    final source = File(
      'supabase/migrations/0012_fishing_spot_moderation.sql',
    ).readAsStringSync();

    expect(source, contains('create policy "admins read all fishing spots"'));
    expect(source, contains('create policy "admins update fishing spots"'));
    expect(source, contains('public.is_admin()'));
    expect(source, contains('grant update on table public.fishing_spots'));
    expect(source,
        contains('revoke insert, delete on table public.fishing_spots'));
  });
}
