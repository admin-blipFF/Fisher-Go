import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hosted habitat verifier checks stable fish IDs and project identity',
      () {
    final tool = File('tool/verify_supabase_fishing_spot_habitat.dart');
    final workflow = File('.github/workflows/supabase-content-release.yml');

    expect(tool.existsSync(), isTrue);
    expect(workflow.existsSync(), isTrue);
    final source = tool.readAsStringSync();
    final workflowSource = workflow.readAsStringSync();

    expect(source, contains('SUPABASE_URL'));
    expect(source, contains('SUPABASE_ANON_KEY'));
    expect(source, contains('SUPABASE_PROJECT_REF'));
    expect(source, contains('SUPABASE_EXPECTED_PROJECT_REF'));
    expect(source, contains('isTrustedSupabaseUrl'));
    expect(source, contains('/rest/v1/fishing_spots'));
    expect(source, contains('P017'));
    for (final spotId in [
      'P018',
      'P036',
      'P043',
      'P046',
      'P047',
      'P050',
      'P052',
      'P053',
      'P054',
    ]) {
      expect(
        source,
        contains("'$spotId'"),
        reason: 'hosted habitat verifier must cover $spotId',
      );
    }
    expect(source, contains('P035'));
    expect(source, contains('P045'));
    expect(source, contains('P051'));
    expect(source, contains('fish-103'));
    expect(source, contains('fish-063'));
    expect(source, contains('fish-073'));
    expect(source, contains('fish-140'));
    expect(source, contains('exitCode = 2'));
    expect(source, contains('_operationTimeout'));
    expect(source, isNot(contains('SERVICE_ROLE')));
    expect(source, isNot(contains('print(Platform.environment')));

    expect(
      workflowSource,
      contains('verify_supabase_fishing_spot_habitat.dart'),
    );
    expect(
      workflowSource,
      contains(
          r'SUPABASE_EXPECTED_PROJECT_REF: ${{ needs.apply-and-verify.outputs.project_ref }}'),
    );
    expect(workflowSource,
        contains(r'SUPABASE_ANON_KEY: ${{ secrets.SUPABASE_ANON_KEY }}'));
  });
}
