import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('auth upgrade smoke uses bounded REST identity preservation', () {
    final source = File(
      'tool/verify_supabase_auth_upgrade.dart',
    ).readAsStringSync();

    expect(source, contains('FISHERGO_SMOKE_UPGRADE_EMAIL'));
    expect(source, contains('FISHERGO_SMOKE_UPGRADE_PASSWORD'));
    expect(source, contains("'/auth/v1/signup'"));
    expect(source, contains("'/auth/v1/user'"));
    expect(source, contains("'redirect_to'"));
    expect(source, contains('bounded HTTP client'));
    expect(source, contains('anonymousUserId'));
    expect(source, contains('anonymousIsAnonymous'));
    expect(source, contains("['is_anonymous']"));
    expect(source, contains('upgradedUserId'));
    expect(source, contains('upgradedIsAnonymous'));
    expect(source, contains('_operationTimeout'));
    expect(source, contains('_cleanupTimeout'));
    expect(source, contains('client.close()'));
    expect(source, contains('exitCode = 2'));
  });
}
