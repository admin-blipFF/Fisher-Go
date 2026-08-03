import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('account deletion release workflow deploys and smoke-tests the function',
      () {
    final workflow = File(
      '.github/workflows/supabase-account-deletion-release.yml',
    ).readAsStringSync();

    expect(workflow, contains('workflow_dispatch:'));
    expect(workflow, contains('flutter pub get'));
    expect(workflow, contains('flutter test --no-pub'));
    expect(workflow, contains('concurrency:'));
    expect(workflow, contains('group: fishergo-account-deletion-release'));
    expect(workflow, contains('cancel-in-progress: false'));
    expect(
        workflow, contains('environment: fishergo-account-deletion-release'));
    final preflightStep = workflow.indexOf(
      'name: Verify protected deletion inputs before deploy',
    );
    final setupFlutterStep = workflow.indexOf('name: Set up Flutter');
    final deployStep = workflow.indexOf(
      'name: Deploy protected delete-account function',
    );
    expect(preflightStep, greaterThanOrEqualTo(0));
    expect(setupFlutterStep, greaterThanOrEqualTo(0));
    expect(preflightStep, lessThan(setupFlutterStep));
    expect(deployStep, greaterThanOrEqualTo(0));
    expect(preflightStep, lessThan(deployStep));
    final preflightSource = workflow.substring(preflightStep, deployStep);
    for (final secret in [
      'SUPABASE_ACCESS_TOKEN',
      'SUPABASE_PROJECT_REF',
      'SUPABASE_URL',
      'SUPABASE_ANON_KEY',
      'SUPABASE_SERVICE_ROLE_KEY',
      'FISHERGO_SMOKE_DELETION_EMAIL',
      'FISHERGO_SMOKE_DELETION_PASSWORD',
    ]) {
      expect(
        preflightSource,
        contains('test -n "\$$secret"'),
        reason: 'deletion release must require $secret before deploy',
      );
    }
    expect(
        workflow,
        contains(
            r'SUPABASE_ACCESS_TOKEN: ${{ secrets.SUPABASE_ACCESS_TOKEN }}'));
    expect(workflow,
        contains(r'SUPABASE_PROJECT_REF: ${{ secrets.SUPABASE_PROJECT_REF }}'));
    expect(workflow,
        contains(r'SUPABASE_URL: ${{ secrets.SUPABASE_URL }}'));
    expect(workflow,
        contains(r'SUPABASE_ANON_KEY: ${{ secrets.SUPABASE_ANON_KEY }}'));
    expect(workflow, contains('verify_supabase_project_identity.dart'));
    expect(workflow, contains('supabase functions deploy delete-account'));
    expect(workflow, contains('tool/verify_supabase_account_deletion.dart'));
    expect(
        workflow,
        contains(
            r'SUPABASE_SERVICE_ROLE_KEY: ${{ secrets.SUPABASE_SERVICE_ROLE_KEY }}'));
    expect(workflow, isNot(contains('continue-on-error: true')));
  });

  test('account deletion smoke uses bounded authenticated REST calls', () {
    final source = File(
      'tool/verify_supabase_account_deletion.dart',
    ).readAsStringSync();

    expect(source, contains('/auth/v1/signup'));
    expect(source, contains('/functions/v1/delete-account'));
    expect(source, contains("['deleted'] != true"));
    expect(source, contains('/auth/v1/user'));
    expect(source, contains('SUPABASE_SERVICE_ROLE_KEY'));
    expect(source, contains('_headers(serviceRoleKey, serviceRoleKey)'));
    expect(source, contains('timeout('));
    expect(source, isNot(contains('print(Platform.environment')));
  });
}
