import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('delete-account function authenticates and removes user-owned data', () {
    final source = File(
      'supabase/functions/delete-account/index.ts',
    ).readAsStringSync();

    expect(source, contains('Authorization'));
    expect(source, contains('auth.getUser()'));
    expect(source, contains('auth.admin.deleteUser'));
    expect(source, contains('"player_profiles"'));
    expect(source, contains('"player_fish_collections"'));
    expect(source, contains('"player_catches"'));
    expect(source, contains('"profiles"'));
    expect(source, contains('"catches"'));
    expect(source, contains('"daily_leaderboard"'));
    expect(source, contains('"coin_grant_claims"'));
    expect(source, contains('column: "id"'));
    expect(source, contains('column: "user_id"'));
    expect(source, contains('"catch-photos"'));
    expect(source, contains('.remove('));
    expect(source, contains('SUPABASE_SERVICE_ROLE_KEY'));
    expect(source, isNot(contains('service_role_key=')));
  });

  test('delete-account is explicitly protected by Supabase JWT verification',
      () {
    final config = File('supabase/config.toml').readAsStringSync();

    expect(config, contains('[functions.delete-account]'));
    expect(config, contains('verify_jwt = true'));
  });

  test('catch-photo deletion does not skip objects after removing a page', () {
    final source = File(
      'supabase/functions/delete-account/index.ts',
    ).readAsStringSync();

    expect(source, contains('offset: 0'));
    expect(source, isNot(contains('offset += data.length')));
  });
}
