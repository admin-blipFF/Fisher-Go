import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    '${Directory.current.path}${Platform.pathSeparator}'
    'supabase${Platform.pathSeparator}migrations${Platform.pathSeparator}'
    '0005_repair_player_rls.sql',
  );
  final legacyMigration = File(
    '${Directory.current.path}${Platform.pathSeparator}'
    'supabase${Platform.pathSeparator}migrations${Platform.pathSeparator}'
    '001_player_cloud_sync.sql',
  );

  test('player tables require authenticated ownership', () {
    final sql = migration.readAsStringSync().toLowerCase();

    expect(sql, contains('user_id = auth.uid()::text'));
    expect(sql, contains('to authenticated'));
    expect(
        sql, contains('revoke all on table public.player_profiles from anon'));
    expect(
      sql,
      contains('revoke all on table public.player_fish_collections from anon'),
    );
    expect(
        sql, contains('revoke all on table public.player_catches from anon'));
    expect(
      sql,
      contains(
        'grant select, insert, update, delete\n  on table public.catches to authenticated',
      ),
    );
    expect(sql, contains('users delete their own catches'));
    expect(sql, contains('users read their own profile'));
    expect(sql, contains('revoke all on table public.profiles from anon'));
    expect(sql, isNot(contains('using (true)')));
    expect(sql, isNot(contains('with check (true)')));
  });

  test('catalog is no longer writable through the public client', () {
    final sql = migration.readAsStringSync().toLowerCase();

    expect(sql, contains('drop policy if exists "fish_species_anon_insert"'));
    expect(sql,
        contains('revoke insert, update, delete on table public.fish_species'));
  });

  test('pending migration bundle cannot reintroduce permissive player policies',
      () {
    final sql = migration.readAsStringSync().toLowerCase();
    final legacySql = legacyMigration.readAsStringSync().toLowerCase();

    expect(sql, contains('create table if not exists public.player_profiles'));
    expect(
      sql,
      contains('create table if not exists public.player_fish_collections'),
    );
    expect(sql, contains('create table if not exists public.player_catches'));
    expect(legacySql, isNot(contains('using (true)')));
    expect(legacySql, isNot(contains('with check (true)')));
  });

  test('fishing spot registry exposes only auditable verified seed rows', () {
    final sql = File(
      '${Directory.current.path}${Platform.pathSeparator}'
      'supabase${Platform.pathSeparator}migrations${Platform.pathSeparator}'
      '0006_create_fishing_spots.sql',
    ).readAsStringSync().toLowerCase();

    expect(sql, contains('create table if not exists public.fishing_spots'));
    expect(sql, contains("verification_status = 'verified'"));
    expect(sql, contains('public reads active verified fishing spots'));
    expect(
        sql,
        contains(
            'revoke insert, update, delete on table public.fishing_spots'));
    expect(sql, contains('insert into public.fishing_spots'));
    expect(sql, contains('fishergo geocoded spot seed'));
    expect(sql, contains('on conflict (id) do update'));
  });

  test('catch photos use a private user-owned storage bucket', () {
    final sql = File(
      '${Directory.current.path}${Platform.pathSeparator}'
      'supabase${Platform.pathSeparator}migrations${Platform.pathSeparator}'
      '0010_catch_photos_storage.sql',
    ).readAsStringSync().toLowerCase();

    expect(sql, contains("values ('catch-photos', 'catch-photos', false)"));
    expect(sql, contains("bucket_id = 'catch-photos'"));
    expect(sql, contains('(storage.foldername(name))[1] = auth.uid()::text'));
    expect(sql, contains('to authenticated'));
    expect(sql, isNot(contains('to anon')));
  });

  test('catch records keep private photo paths separate from URL fields', () {
    final sql = File(
      '${Directory.current.path}${Platform.pathSeparator}'
      'supabase${Platform.pathSeparator}migrations${Platform.pathSeparator}'
      '0011_catch_photo_storage_path.sql',
    ).readAsStringSync().toLowerCase();

    expect(sql, contains('add column if not exists photo_storage_path text'));
    expect(sql, contains('catches_photo_storage_path_idx'));
  });

  test('linked test-runner grants are safe when the role is absent locally',
      () {
    final sql = File(
      '${Directory.current.path}${Platform.pathSeparator}'
      'supabase${Platform.pathSeparator}migrations${Platform.pathSeparator}'
      '002_grant_linked_test_runner_access.sql',
    ).readAsStringSync().toLowerCase();

    expect(sql, contains('from pg_roles'));
    expect(sql, contains('cli_login_postgres'));
    expect(sql, contains('execute'));
  });
}
