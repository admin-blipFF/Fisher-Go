import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hosted audit is manual, read-only, and scoped to public checks', () {
    final workflow = File(
      '.github/workflows/supabase-hosted-audit.yml',
    ).readAsStringSync();

    expect(workflow, contains('workflow_dispatch:'));
    expect(workflow, contains('expected_project_ref:'));
    expect(workflow, contains('environment: fishergo-live-smoke'));
    expect(workflow, contains('concurrency:'));
    expect(workflow, contains('group: fishergo-hosted-audit'));
    final preflightStep = workflow.indexOf(
      'name: Verify protected hosted audit inputs before setup',
    );
    final setupFlutterStep = workflow.indexOf('name: Set up Flutter');
    final identityStep = workflow.indexOf('name: Verify canonical project identity');
    expect(preflightStep, greaterThanOrEqualTo(0));
    expect(setupFlutterStep, greaterThan(preflightStep));
    expect(identityStep, greaterThan(setupFlutterStep));
    final preflightSource = workflow.substring(preflightStep, setupFlutterStep);
    for (final secret in [
      'SUPABASE_URL',
      'SUPABASE_ANON_KEY',
      'SUPABASE_PROJECT_REF',
    ]) {
      expect(
        preflightSource,
        contains('test -n "\$$secret"'),
        reason: 'hosted audit must require $secret before setup',
      );
    }
    expect(workflow,
        contains('dart run tool/verify_supabase_project_identity.dart'));
    expect(workflow,
        contains('dart run tool/verify_supabase_auth_provider_config.dart'));
    expect(workflow,
        contains('dart run tool/verify_supabase_fishing_spot_habitat.dart'));
    expect(
      workflow,
      contains(
        r'SUPABASE_EXPECTED_PROJECT_REF: ${{ inputs.expected_project_ref }}',
      ),
    );
    expect(workflow, contains('if: always()'));
    expect(workflow, contains('GITHUB_STEP_SUMMARY'));
    expect(workflow, contains('Read-only checks'));
    expect(workflow, contains('does not request or use a database password'));
    expect(workflow, isNot(contains('SUPABASE_DB_PASSWORD')));
    expect(workflow, isNot(contains('SUPABASE_ACCESS_TOKEN')));
    expect(workflow, isNot(contains('supabase db push')));
    expect(workflow, isNot(contains('supabase link')));
  });
}
