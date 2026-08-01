import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hosted event configuration smoke verifies the server projection', () {
    final tool = File('tool/verify_supabase_event_config.dart');
    final workflow = File('.github/workflows/supabase-content-release.yml');
    final source = tool.readAsStringSync();
    final workflowSource = workflow.readAsStringSync();

    expect(source, contains('/auth/v1/signup'));
    expect(source, contains('/rest/v1/rpc/get_active_fishing_event_config'));
    expect(source, contains('SUPABASE_EXPECTED_PROJECT_REF'));
    expect(source, contains('invalid multiplier'));
    expect(source, contains('/auth/v1/logout'));
    expect(source, isNot(contains('SERVICE_ROLE')));
    expect(workflowSource, contains('verify_supabase_event_config.dart'));
  });
}
