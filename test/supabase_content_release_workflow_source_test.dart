import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('content release workflow provides an owner-controlled linked deploy',
      () {
    final workflow = File(
      '.github/workflows/supabase-content-release.yml',
    ).readAsStringSync();

    expect(workflow, contains('workflow_dispatch:'));
    expect(workflow, contains('reconcile_legacy_history:'));
    expect(workflow, contains('type: boolean'));
    expect(workflow, contains('concurrency:'));
    expect(workflow, contains('group: fishergo-content-release'));
    expect(workflow, contains('cancel-in-progress: false'));
    expect(workflow, contains('environment: fishergo-content-release'));
    expect(workflow, contains('supabase/setup-cli@v1'));
    expect(workflow, contains('flutter test --no-pub'));
    expect(workflow, contains('test/analytics_ingestion_source_test.dart'));
    expect(workflow,
        contains('test/supabase_analytics_ingestion_source_test.dart'));
    expect(workflow, contains('test/security/supabase_ci_source_test.dart'));
    expect(workflow, contains('test/server_gameplay_session_source_test.dart'));
    expect(
      workflow,
      contains('test/supabase_legacy_rls_smoke_source_test.dart'),
    );
    expect(workflow, contains('supabase link --project-ref'));
    expect(
      workflow,
      contains('SUPABASE_LEGACY_HISTORY_REPAIR_CONFIRMATION'),
    );
    expect(
      workflow,
      contains(
        'supabase migration repair 001 002 --linked --status reverted --yes',
      ),
    );
    expect(workflow, contains('FISHERGO_REPAIR_001_002'));
    expect(workflow,
        contains('rm -f supabase/migrations/001_player_cloud_sync.sql'));
    expect(
      workflow,
      contains('test ! -e supabase/migrations/001_player_cloud_sync.sql'),
    );
    expect(
      workflow,
      contains(
          'rm -f supabase/migrations/002_grant_linked_test_runner_access.sql'),
    );
    expect(
      workflow,
      contains(
          'test ! -e supabase/migrations/002_grant_linked_test_runner_access.sql'),
    );
    expect(
      workflow,
      contains('supabase db push --linked --include-all --dry-run'),
    );
    expect(workflow, contains('supabase db push --linked --include-all'));
    expect(workflow, contains('supabase test db --linked'));
    expect(
      workflow,
      contains(r'''supabase test db --linked supabase/tests/remote_player_rls_shape_test.sql \
            supabase/tests/remote_player_rls_behavior_test.sql'''),
    );
    for (final path in [
      'supabase/tests/analytics_events_shape_test.sql',
      'supabase/tests/analytics_retention_shape_test.sql',
      'supabase/tests/catch_photo_bucket_shape_test.sql',
      'supabase/tests/fishing_spot_content_shape_test.sql',
      'supabase/tests/fishing_spot_moderation_shape_test.sql',
      'supabase/tests/gameplay_reward_ticket_shape_test.sql',
      'supabase/tests/gameplay_session_shape_test.sql',
      'supabase/tests/real_catch_moderation_shape_test.sql',
      'supabase/tests/server_authoritative_rewards_shape_test.sql',
      'supabase/tests/server_event_config_shape_test.sql',
    ]) {
      expect(
        workflow,
        contains(path),
        reason: 'hosted content release must verify $path',
      );
    }
    expect(
      workflow,
      contains('supabase db lint --linked --schema public --fail-on error'),
    );
    expect(workflow, contains('hosted-gameplay-smoke'));
    expect(workflow, contains('needs: apply-and-verify'));
    expect(workflow, contains('outputs:'));
    expect(workflow, contains('id: release-target'));
    expect(
      workflow,
      contains(r'project_ref: ${{ steps.release-target.outputs.project_ref }}'),
    );
    expect(workflow, contains('GITHUB_OUTPUT'));
    expect(workflow, contains('environment: fishergo-live-smoke'));
    expect(workflow,
        contains('dart run tool/verify_supabase_gameplay_session.dart'));
    expect(workflow,
        contains('dart run tool/verify_supabase_analytics_ingestion.dart'));
    expect(workflow,
        contains('dart run tool/verify_supabase_event_config.dart'));
    expect(
      workflow,
      contains(r'SUPABASE_URL: ${{ secrets.SUPABASE_URL }}'),
    );
    expect(
      workflow,
      contains(r'SUPABASE_ANON_KEY: ${{ secrets.SUPABASE_ANON_KEY }}'),
    );
    expect(
      workflow,
      contains(r'SUPABASE_ACCESS_TOKEN: ${{ secrets.SUPABASE_ACCESS_TOKEN }}'),
    );
    expect(
      workflow,
      contains(r'SUPABASE_PROJECT_REF: ${{ secrets.SUPABASE_PROJECT_REF }}'),
    );
    expect(
      workflow,
      contains(r'SUPABASE_DB_PASSWORD: ${{ secrets.SUPABASE_DB_PASSWORD }}'),
    );
    expect(workflow, isNot(contains('continue-on-error: true')));
    expect(workflow, isNot(contains(r'echo "$SUPABASE')));
  });
}
