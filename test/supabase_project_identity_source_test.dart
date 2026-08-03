import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('live smoke verifies Supabase project identity before remote checks',
      () {
    final tool = File('tool/verify_supabase_project_identity.dart');
    final workflow = File('.github/workflows/supabase-live-smoke.yml');

    expect(tool.existsSync(), isTrue);
    expect(workflow.existsSync(), isTrue);
    final source = tool.readAsStringSync();
    final workflowSource = workflow.readAsStringSync();

    expect(source, contains('SUPABASE_URL'));
    expect(source, contains('SUPABASE_ANON_KEY'));
    expect(source, contains('SUPABASE_PROJECT_REF'));
    expect(source, contains('isTrustedSupabaseUrl'));
    expect(source, contains('/auth/v1/settings'));
    expect(source, contains('_operationTimeout'));
    expect(source, contains('exitCode = 2'));
    expect(source, isNot(contains('SERVICE_ROLE')));
    expect(source, isNot(contains('print(Platform.environment')));

    expect(
      workflowSource,
      contains('tool/verify_supabase_project_identity.dart'),
    );
    expect(
      workflowSource,
      contains(r'SUPABASE_PROJECT_REF: ${{ secrets.SUPABASE_PROJECT_REF }}'),
    );
  });
}
