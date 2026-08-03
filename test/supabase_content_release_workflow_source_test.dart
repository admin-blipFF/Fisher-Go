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
    final preflightStep = workflow.indexOf(
      'name: Verify protected release inputs before mutation',
    );
    final setupFlutterStep = workflow.indexOf('name: Set up Flutter');
    final migrationStep = workflow.indexOf(
      'name: Link and apply migrations',
    );
    expect(preflightStep, greaterThanOrEqualTo(0));
    expect(setupFlutterStep, greaterThanOrEqualTo(0));
    expect(preflightStep, lessThan(setupFlutterStep));
    expect(migrationStep, greaterThanOrEqualTo(0));
    expect(preflightStep, lessThan(migrationStep));
    final preflightEnd = workflow.indexOf('name: Link and apply migrations',
        preflightStep);
    final preflightSource = workflow.substring(preflightStep, preflightEnd);
    for (final secret in [
      'SUPABASE_ACCESS_TOKEN',
      'SUPABASE_PROJECT_REF',
      'SUPABASE_URL',
      'SUPABASE_ANON_KEY',
      'SUPABASE_DB_PASSWORD',
      'FISHERGO_RLS_USER_A_EMAIL',
      'FISHERGO_RLS_USER_A_PASSWORD',
      'FISHERGO_RLS_USER_B_EMAIL',
      'FISHERGO_RLS_USER_B_PASSWORD',
    ]) {
      expect(
        preflightSource,
        contains('test -n "\$$secret"'),
        reason: 'migration mutation must require $secret first',
      );
    }
    expect(
      preflightSource,
      contains('SUPABASE_LEGACY_HISTORY_REPAIR_CONFIRMATION'),
    );
    expect(
      preflightSource,
      contains('FISHERGO_REPAIR_001_002'),
    );
    expect(preflightSource, isNot(contains('supabase link')));
    expect(preflightSource, isNot(contains('supabase db push')));
    final migrationStepEnd = workflow.indexOf(
      'name: Export linked project ref',
      migrationStep,
    );
    expect(migrationStepEnd, greaterThan(migrationStep));
    final migrationSource = workflow.substring(migrationStep, migrationStepEnd);
    expect(
      migrationSource,
      contains(r'SUPABASE_URL: ${{ secrets.SUPABASE_URL }}'),
    );
    expect(
      migrationSource,
      contains(r'SUPABASE_ANON_KEY: ${{ secrets.SUPABASE_ANON_KEY }}'),
    );
    final identityCheck = migrationSource.indexOf(
      'dart run tool/verify_supabase_project_identity.dart',
    );
    final linkCommand = migrationSource.indexOf('supabase link --project-ref');
    expect(identityCheck, greaterThanOrEqualTo(0));
    expect(linkCommand, greaterThan(identityCheck));
    expect(workflow, contains('name: Upload Supabase migration evidence'));
    expect(workflow, contains('if: always()'));
    expect(workflow, contains('actions/upload-artifact@v4'));
    expect(workflow, contains('fishergo-migration-history-before.txt'));
    expect(workflow, contains('fishergo-migration-plan.txt'));
    expect(workflow, contains('fishergo-migration-history-after.txt'));
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
    expect(
      workflow,
      contains(r'plan_file="$RUNNER_TEMP/fishergo-migration-plan.txt"'),
    );
    expect(
      workflow,
      contains(r'2>&1 | tee "$plan_file"'),
    );
    expect(
      workflow,
      contains('dart run tool/verify_supabase_migration_plan.dart'),
    );
    expect(workflow, contains(r'--plan-file="$plan_file"'));
    expect(workflow, contains(r'--allowed="$allowed_ids"'));
    expect(workflow, contains('supabase db push --linked --include-all'));
    expect(workflow, contains('supabase test db --linked'));
    expect(
      workflow,
      contains(
          r'''supabase test db --linked supabase/tests/remote_player_rls_shape_test.sql \
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
      'supabase/tests/notification_device_tokens_shape_test.sql',
      'supabase/tests/notification_device_tokens_behavior_test.sql',
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
    expect(
        workflow, contains('dart run tool/verify_supabase_event_config.dart'));
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
    final smokeJob = workflow.indexOf('hosted-gameplay-smoke:');
    expect(smokeJob, greaterThanOrEqualTo(0));
    final smokePreflight = workflow.indexOf(
      'name: Verify protected live smoke inputs before setup',
      smokeJob,
    );
    final smokeSetup = workflow.indexOf('name: Set up Flutter', smokeJob);
    expect(smokePreflight, greaterThanOrEqualTo(smokeJob));
    expect(smokeSetup, greaterThan(smokePreflight));
    final smokePreflightSource = workflow.substring(smokePreflight, smokeSetup);
    for (final secret in [
      'SUPABASE_URL',
      'SUPABASE_ANON_KEY',
      'SUPABASE_PROJECT_REF',
    ]) {
      expect(
        smokePreflightSource,
        contains('test -n "\$$secret"'),
        reason: 'hosted smoke must require $secret before setup',
      );
    }
    expect(
      smokePreflightSource,
      contains(r'test "$SUPABASE_PROJECT_REF" = "${{ needs.apply-and-verify.outputs.project_ref }}"'),
    );
    final smokeIdentity = workflow.indexOf(
      'name: Verify Supabase project identity',
      smokeJob,
    );
    final smokeHabitat = workflow.indexOf(
      'dart run tool/verify_supabase_fishing_spot_habitat.dart',
      smokeJob,
    );
    expect(smokeIdentity, greaterThanOrEqualTo(smokeJob));
    expect(smokeHabitat, greaterThan(smokeIdentity));
    expect(
      workflow,
      contains(
        r'SUPABASE_EXPECTED_PROJECT_REF: ${{ needs.apply-and-verify.outputs.project_ref }}',
      ),
    );
    expect(
      workflow,
      contains(
        r'test "$SUPABASE_PROJECT_REF" = "${{ needs.apply-and-verify.outputs.project_ref }}"',
      ),
    );
    expect(
      workflow,
      contains(r'SUPABASE_DB_PASSWORD: ${{ secrets.SUPABASE_DB_PASSWORD }}'),
    );
    expect(workflow, isNot(contains('continue-on-error: true')));
    expect(workflow, isNot(contains(r'echo "$SUPABASE')));
  });
}
