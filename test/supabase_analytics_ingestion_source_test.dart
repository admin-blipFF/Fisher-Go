import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hosted analytics smoke verifies identity before ingestion', () {
    final tool = File(
      'tool/verify_supabase_analytics_ingestion.dart',
    ).readAsStringSync();
    final workflow = File(
      '.github/workflows/supabase-content-release.yml',
    ).readAsStringSync();

    expect(tool, contains("'/auth/v1/signup'"));
    expect(tool, contains("'/rest/v1/rpc/record_analytics_event'"));
    expect(tool, contains('SUPABASE_EXPECTED_PROJECT_REF'));
    expect(tool, contains('FISHERGO_SMOKE_EMAIL'));
    expect(tool, contains('FISHERGO_SMOKE_PASSWORD'));
    expect(tool, contains('p_event_name'));
    expect(tool, contains("eventName: 'map_idle'"));
    expect(tool, contains("'durationMs': 1320"));
    expect(tool, contains('_postAnalyticsEvent'));
    expect(tool, contains('email'));
    expect(tool, contains('.delete('));
    expect(tool, contains('disposable account cleanup'));
    expect(tool, contains('deletionSucceeded'));
    expect(tool, contains('exitCode = 2'));
    expect(workflow, contains('verify_supabase_analytics_ingestion.dart'));
    expect(workflow, contains('SUPABASE_EXPECTED_PROJECT_REF'));
  });
}
