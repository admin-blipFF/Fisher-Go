import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('retention reporting is an admin-only aggregate boundary', () {
    final migration = File(
      'supabase/migrations/0021_admin_retention_report.sql',
    ).readAsStringSync().toLowerCase();

    expect(migration, contains('analytics_retention_report'));
    expect(migration, contains('security definer'));
    expect(migration, contains('public.is_admin()'));
    expect(migration, contains('day_2_returners'));
    expect(migration, contains('day_7_returners'));
    expect(migration, contains('revoke all on function'));
    expect(migration, contains('actor_key'));
  });

  test('admin UI consumes aggregate retention data without raw events', () {
    final service =
        File('lib/core/admin/admin_ops_service.dart').readAsStringSync();
    final screen = File('lib/features/admin/presentation/admin_screen.dart')
        .readAsStringSync();

    expect(service, contains('analytics_retention_report'));
    expect(service, contains('AnalyticsRetentionCohort'));
    expect(screen, contains('玩家留存（D2 / D7）'));
    expect(screen, contains('loadRetentionReport'));
    expect(screen, isNot(contains('analytics_events')));
  });
}
