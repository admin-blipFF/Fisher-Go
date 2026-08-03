import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Supabase live smoke workflow is manual and fails closed', () {
    final source = File(
      '.github/workflows/supabase-live-smoke.yml',
    ).readAsStringSync();

    expect(source, contains('workflow_dispatch:'));
    expect(source, contains('permissions:'));
    expect(source, contains('contents: read'));
    expect(source, contains('concurrency:'));
    expect(source, contains('group: fishergo-live-smoke'));
    expect(source, contains('cancel-in-progress: false'));
    expect(source, contains('flutter pub get'));
    expect(source, contains('tool/verify_supabase_auth_upgrade.dart'));
    expect(source, contains('tool/verify_supabase_catch_photo_storage.dart'));
    expect(source, contains('tool/verify_supabase_analytics_ingestion.dart'));
    final preflightStep = source.indexOf(
      'Verify protected live smoke inputs before remote checks',
    );
    final setupFlutterStep = source.indexOf('name: Set up Flutter');
    final identityStep = source.indexOf('Verify Supabase project identity');
    final providerStep = source.indexOf('Verify Auth provider configuration');
    expect(preflightStep, greaterThanOrEqualTo(0));
    expect(setupFlutterStep, greaterThanOrEqualTo(0));
    expect(preflightStep, lessThan(setupFlutterStep));
    expect(identityStep, greaterThanOrEqualTo(0));
    expect(providerStep, greaterThanOrEqualTo(0));
    expect(preflightStep, lessThan(identityStep));
    final preflightSource = source.substring(preflightStep, identityStep);
    for (final secret in [
      'SUPABASE_URL',
      'SUPABASE_ANON_KEY',
      'SUPABASE_PROJECT_REF',
      'FISHERGO_SMOKE_UPGRADE_EMAIL',
      'FISHERGO_SMOKE_UPGRADE_PASSWORD',
    ]) {
      expect(
        preflightSource,
        contains('test -n "\$$secret"'),
        reason: 'live smoke must require $secret before remote checks',
      );
    }
    expect(identityStep, lessThan(providerStep));
    final analyticsStep = source.indexOf('Verify analytics ingestion');
    expect(analyticsStep, greaterThan(identityStep));
    expect(analyticsStep, lessThan(providerStep));
    expect(source, contains(r'SUPABASE_URL: ${{ secrets.SUPABASE_URL }}'));
    expect(
      source,
      contains(r'SUPABASE_ANON_KEY: ${{ secrets.SUPABASE_ANON_KEY }}'),
    );
    expect(
      source,
      contains(r'SUPABASE_PROJECT_REF: ${{ secrets.SUPABASE_PROJECT_REF }}'),
    );
    expect(
      source,
      contains(
        r'FISHERGO_SMOKE_UPGRADE_EMAIL: ${{ secrets.FISHERGO_SMOKE_UPGRADE_EMAIL }}',
      ),
    );
    expect(
      source,
      contains(
        r'FISHERGO_SMOKE_UPGRADE_PASSWORD: ${{ secrets.FISHERGO_SMOKE_UPGRADE_PASSWORD }}',
      ),
    );
    expect(source, contains("FISHERGO_SMOKE_ANONYMOUS: 'true'"));
    expect(source, isNot(contains('FISHERGO_SMOKE_EMAIL')));
    expect(source, isNot(contains('FISHERGO_SMOKE_PASSWORD')));
    expect(source, isNot(contains('continue-on-error: true')));
  });
}
