import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Auth provider verifier checks public Google and anonymous settings',
      () {
    final source = File(
      'tool/verify_supabase_auth_provider_config.dart',
    ).readAsStringSync();

    expect(source, contains("'/auth/v1/settings'"));
    expect(source, contains("'external'"));
    expect(source, contains("'google'"));
    expect(source, contains("'anonymous_users'"));
    expect(source, contains('FISHERGO_REQUIRE_GOOGLE_PROVIDER'));
    expect(source, contains('FISHERGO_REQUIRE_ANONYMOUS_PROVIDER'));
    expect(source, contains('requireAnonymous'));
    expect(source, contains('_operationTimeout'));
    expect(source, contains('client.close()'));
    expect(source, contains('exitCode = 2'));
    expect(source, isNot(contains('SUPABASE_SERVICE_ROLE_KEY')));
  });

  test('live smoke workflow verifies provider configuration before auth flows',
      () {
    final source = File(
      '.github/workflows/supabase-live-smoke.yml',
    ).readAsStringSync();

    expect(source, contains('tool/verify_supabase_auth_provider_config.dart'));
    expect(source, contains("FISHERGO_REQUIRE_GOOGLE_PROVIDER: 'true'"));
    expect(
      source,
      contains("FISHERGO_REQUIRE_ANONYMOUS_PROVIDER: 'true'"),
    );
  });
}
