import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Web release verifies protected inputs before build setup', () {
    final source = File('.github/workflows/web-release.yml').readAsStringSync();

    final checkoutStep = source.indexOf('name: Checkout');
    final preflightStep = source.indexOf(
      'name: Verify protected Web release inputs before build',
    );
    final setupFlutterStep = source.indexOf('name: Set up Flutter');
    expect(checkoutStep, greaterThanOrEqualTo(0));
    expect(preflightStep, greaterThan(checkoutStep));
    expect(setupFlutterStep, greaterThan(preflightStep));

    final preflightSource = source.substring(preflightStep, setupFlutterStep);
    for (final secret in [
      'VERCEL_TOKEN',
      'SUPABASE_URL',
      'SUPABASE_ANON_KEY',
      'SUPABASE_PROJECT_REF',
      'FISHERGO_PRIVACY_URL',
      'FISHERGO_SUPPORT_EMAIL',
    ]) {
      expect(
        preflightSource,
        contains('test -n "\$$secret"'),
        reason: 'Web release must require $secret before build setup',
      );
    }
  });
}
