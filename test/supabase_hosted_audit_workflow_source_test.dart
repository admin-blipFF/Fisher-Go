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
