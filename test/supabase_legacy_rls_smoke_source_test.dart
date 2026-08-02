import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy RLS smoke resolves two protected Auth users', () {
    final tool = File('tool/prepare_supabase_legacy_rls_test.dart');
    final template = File('tool/templates/legacy_auth_rls_test.sql');
    final workflow = File(
      '.github/workflows/supabase-content-release.yml',
    );

    expect(tool.existsSync(), isTrue);
    expect(template.existsSync(), isTrue);
    final toolSource = tool.readAsStringSync();
    final templateSource = template.readAsStringSync().toLowerCase();
    final workflowSource = workflow.readAsStringSync();

    expect(toolSource, contains('FISHERGO_RLS_USER_A_EMAIL'));
    expect(toolSource, contains('FISHERGO_RLS_USER_A_PASSWORD'));
    expect(toolSource, contains('FISHERGO_RLS_USER_B_EMAIL'));
    expect(toolSource, contains('FISHERGO_RLS_USER_B_PASSWORD'));
    expect(toolSource, contains('/auth/v1/token?grant_type=password'));
    expect(toolSource, contains('__FISHERGO_USER_A__'));
    expect(toolSource, contains('__FISHERGO_USER_B__'));
    expect(toolSource, contains('exitCode = 2'));
    expect(templateSource, contains('begin;'));
    expect(templateSource, contains('rollback;'));
    expect(templateSource, contains('auth.uid()'));
    expect(
        templateSource, contains('user a cannot insert user b legacy profile'));
    expect(
        templateSource, contains('user a cannot insert user b catch record'));
    expect(
        templateSource, contains('user a cannot delete user b catch record'));
    expect(workflowSource, contains('prepare_supabase_legacy_rls_test.dart'));
    expect(workflowSource, contains('FISHERGO_RLS_USER_A_EMAIL'));
    expect(workflowSource, contains('FISHERGO_RLS_USER_A_PASSWORD'));
    expect(workflowSource, contains('FISHERGO_RLS_USER_B_EMAIL'));
    expect(workflowSource, contains('FISHERGO_RLS_USER_B_PASSWORD'));
    expect(workflowSource, contains('supabase test db --linked'));
    expect(workflowSource, contains('tmp/legacy_auth_rls_test.sql'));
  });
}
