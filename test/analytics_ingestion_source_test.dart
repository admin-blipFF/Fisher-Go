import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('analytics ingestion is opt-in and protected at every boundary', () {
    final config = File(
      'lib/core/config/public_app_config.dart',
    ).readAsStringSync();
    final main = File('lib/main.dart').readAsStringSync();
    final sink = File(
      'lib/core/telemetry/supabase_analytics_sink.dart',
    ).readAsStringSync();
    final migration = File(
      'supabase/migrations/0019_privacy_safe_analytics_events.sql',
    ).readAsStringSync();
    final additiveMigration = File(
      'supabase/migrations/0025_analytics_map_idle_event.sql',
    ).readAsStringSync();

    expect(config, contains('FISHERGO_ANALYTICS_ENABLED'));
    expect(config, contains('defaultValue: false'));
    expect(main, contains('SupabaseAnalyticsSink'));
    expect(main, contains('configureSink'));
    expect(sink, contains('record_analytics_event'));
    expect(sink, contains('Supabase.instance.client'));
    expect(sink, contains('batchSize'));
    expect(sink, contains('Analytics is best effort'));
    expect(migration, contains('security definer'));
    expect(migration, contains('digest(auth.uid()::text'));
    expect(migration, contains('jsonb_each(p_fields)'));
    expect(migration, contains("not like '%latitude%'"));
    expect(migration, contains('received_at - interval \'1 minute\''));
    expect(migration, contains('revoke all on table public.analytics_events'));
    expect(additiveMigration, contains('map_idle'));
    expect(additiveMigration, contains('drop constraint if exists'));
    expect(additiveMigration, contains('create or replace function'));
  });

  test('release workflows pass analytics only for protected builds', () {
    final webRelease =
        File('.github/workflows/web-release.yml').readAsStringSync();
    final androidRelease =
        File('.github/workflows/android-release.yml').readAsStringSync();
    final deploy = File('scripts/deploy.sh').readAsStringSync();
    final powershell = File('scripts/deploy.ps1').readAsStringSync();
    final vercelBuild = File('scripts/vercel-build.sh').readAsStringSync();

    expect(webRelease, contains("FISHERGO_ANALYTICS_ENABLED: 'true'"));
    expect(androidRelease, contains("FISHERGO_ANALYTICS_ENABLED: 'true'"));
    expect(androidRelease, contains('secrets.SUPABASE_URL'));
    expect(androidRelease, contains('secrets.SUPABASE_ANON_KEY'));
    expect(deploy, contains('FISHERGO_ANALYTICS_ENABLED'));
    expect(powershell, contains('FISHERGO_ANALYTICS_ENABLED'));
    expect(vercelBuild, contains('FISHERGO_ANALYTICS_ENABLED'));
  });
}
