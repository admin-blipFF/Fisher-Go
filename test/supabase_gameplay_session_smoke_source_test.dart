import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hosted gameplay smoke verifies the server fishing-session boundary',
      () {
    final tool = File('tool/verify_supabase_gameplay_session.dart');
    final workflow = File('.github/workflows/supabase-live-smoke.yml');
    final contentRelease =
        File('.github/workflows/supabase-content-release.yml');

    expect(tool.existsSync(), isTrue);
    expect(workflow.existsSync(), isTrue);
    expect(contentRelease.existsSync(), isTrue);
    final source = tool.readAsStringSync();
    final workflowSource = workflow.readAsStringSync();
    final contentReleaseSource = contentRelease.readAsStringSync();

    expect(source, contains('/auth/v1/signup'));
    expect(source, contains('/rest/v1/fishing_spots'));
    expect(source, contains('/rest/v1/rpc/start_virtual_fishing_session'));
    expect(source, contains('/rest/v1/rpc/resolve_virtual_fishing_session'));
    expect(source, contains('/rest/v1/rpc/claim_gameplay_reward_ticket'));
    expect(source, contains('SUPABASE_PROJECT_REF'));
    expect(source, contains('SUPABASE_EXPECTED_PROJECT_REF'));
    expect(source, contains('FISHERGO_SMOKE_EMAIL'));
    expect(source, contains('FISHERGO_SMOKE_PASSWORD'));
    expect(source, contains('migration target'));
    expect(source, contains('project ref'));
    expect(source, contains('p_pull_elapsed_ms'));
    expect(source, contains('p_player_latitude'));
    expect(source, contains('p_player_longitude'));
    expect(source, contains('p_accuracy_m'));
    expect(source, contains('virtual_catch'));
    expect(source, contains('resolved_miss'));
    expect(source, contains('already_resolved'));
    expect(source, contains('auth/v1/logout'));
    expect(source, contains('uri.path'));
    expect(source, isNot(contains('SERVICE_ROLE')));
    expect(source, contains('_operationTimeout'));
    expect(workflowSource, contains('verify_supabase_gameplay_session.dart'));
    expect(workflowSource, contains('FISHERGO_SMOKE_GAMEPLAY_SPOT_ID'));
    expect(
      contentReleaseSource,
      contains(
          r'SUPABASE_EXPECTED_PROJECT_REF: ${{ needs.apply-and-verify.outputs.project_ref }}'),
    );
    expect(workflowSource, isNot(contains('FISHERGO_SMOKE_EMAIL')));
    expect(workflowSource, isNot(contains('FISHERGO_SMOKE_PASSWORD')));
  });
}
