import 'package:flutter_test/flutter_test.dart';

import '../tool/verify_public_release_config.dart';

void main() {
  test('accepts an HTTPS privacy policy and support email', () {
    expect(
      validatePublicReleaseConfig(
        privacyPolicyUrl: 'https://fisher-go.app/privacy',
        supportEmail: 'support@fisher-go.app',
      ),
      isEmpty,
    );
  });

  test('rejects missing public release metadata', () {
    final issues = validatePublicReleaseConfig(
      privacyPolicyUrl: '',
      supportEmail: '',
    );

    expect(issues, contains('FISHERGO_PRIVACY_URL is required'));
    expect(issues, contains('FISHERGO_SUPPORT_EMAIL is required'));
  });

  test('rejects non-HTTPS policy URLs', () {
    final issues = validatePublicReleaseConfig(
      privacyPolicyUrl: 'http://fisher-go.app/privacy',
      supportEmail: 'support@fisher-go.app',
    );

    expect(issues, contains('FISHERGO_PRIVACY_URL must be an HTTPS URL'));
  });

  test('rejects malformed support email', () {
    final issues = validatePublicReleaseConfig(
      privacyPolicyUrl: 'https://fisher-go.app/privacy',
      supportEmail: 'support fisher-go.app',
    );

    expect(issues, contains('FISHERGO_SUPPORT_EMAIL must be an email address'));
  });
}
