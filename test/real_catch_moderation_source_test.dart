import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('real-catch moderation migration protects the public leaderboard', () {
    final migration = File(
      'supabase/migrations/0023_real_catch_moderation.sql',
    ).readAsStringSync().toLowerCase();

    expect(migration, contains('moderation_status'));
    expect(migration, contains("'pending'"));
    expect(migration, contains("'approved'"));
    expect(migration, contains("'suspended'"));
    expect(migration, contains('guard_catch_moderation'));
    expect(migration, contains('get_public_leaderboard'));
    expect(migration, contains("moderation_status = 'approved'"));
    expect(migration, contains('admins update catches'));
    expect(migration, contains('admins read catch photos'));
  });

  test('admin operations expose a catch moderation queue', () {
    final service =
        File('lib/core/admin/admin_ops_service.dart').readAsStringSync();
    final screen = File('lib/features/admin/presentation/admin_screen.dart')
        .readAsStringSync();

    expect(service, contains('loadCatchesForModeration'));
    expect(service, contains('moderateCatch'));
    expect(service, contains('createSignedUrl'));
    expect(screen, contains('真實釣獲審核'));
    expect(screen, contains('moderateCatch'));
    expect(screen, contains('photo_url'));
  });

  test('release workflow includes catch moderation contracts', () {
    final workflow = File(
      '.github/workflows/supabase-content-release.yml',
    ).readAsStringSync();
    final ci =
        File('test/security/supabase_ci_source_test.dart').readAsStringSync();

    expect(workflow, contains('real_catch_moderation_source_test.dart'));
    expect(ci, contains('real_catch_moderation_shape_test.sql'));
    expect(ci, contains('real_catch_moderation_behavior_test.sql'));
  });
}
