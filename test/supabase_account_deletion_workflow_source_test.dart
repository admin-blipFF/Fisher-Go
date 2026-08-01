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
    expect(
        workflow, contains('environment: fishergo-account-deletion-release'));
    expect(
        workflow,
        contains(
            r'SUPABASE_ACCESS_TOKEN: ${{ secrets.SUPABASE_ACCESS_TOKEN }}'));
    expect(workflow,
        contains(r'SUPABASE_PROJECT_REF: ${{ secrets.SUPABASE_PROJECT_REF }}'));
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
