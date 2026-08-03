import 'package:flutter_test/flutter_test.dart';

import '../tool/verify_supabase_migration_plan.dart';

void main() {
  const allowed = <String>{'0012', '0013', '0026'};

  test('extracts migration ids from apply lines and SQL filenames', () {
    const plan = '''
Applying migration 0012_fishing_spot_moderation.sql...
  0013_real_catch_leaderboard.sql
Applying migration 0026_catch_photo_bucket_constraints.sql...
''';

    final actions = extractMigrationPlanActions(plan);

    expect(actions.map((action) => action.id),
        containsAll(<String>{'0012', '0013', '0026'}));
    expect(actions.every((action) => action.kind == MigrationActionKind.apply),
        isTrue);
  });

  test('accepts an allowed apply plan', () {
    const plan = 'Applying migration 0012_fishing_spot_moderation.sql...';

    expect(
      validateMigrationPlan(plan: plan, allowedMigrationIds: allowed),
      isNull,
    );
  });

  test('rejects legacy and unexpected migration ids', () {
    const legacyPlan = 'Applying migration 001_player_cloud_sync.sql...';
    const unexpectedPlan = 'Applying migration 0030_future_change.sql...';

    expect(
      validateMigrationPlan(
        plan: legacyPlan,
        allowedMigrationIds: allowed,
      ),
      contains('not allowed'),
    );
    expect(
      validateMigrationPlan(
        plan: unexpectedPlan,
        allowedMigrationIds: allowed,
      ),
      contains('not allowed'),
    );
  });

  test('rejects revert actions even when the id is allowed', () {
    const plan = 'Reverting migration 0012_fishing_spot_moderation.sql...';

    expect(
      validateMigrationPlan(plan: plan, allowedMigrationIds: allowed),
      contains('revert'),
    );
  });

  test('accepts an explicit no-op plan and rejects unknown output', () {
    expect(
      validateMigrationPlan(
        plan: 'Remote database is up to date. No migrations to apply.',
        allowedMigrationIds: allowed,
      ),
      isNull,
    );
    expect(
      validateMigrationPlan(
        plan: 'Connecting to remote database...\nWaiting for confirmation.',
        allowedMigrationIds: allowed,
      ),
      contains('No actionable'),
    );
  });
}
