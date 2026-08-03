import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('anonymous profile exposes an account upgrade path', () {
    final source = File(
      'lib/features/profile/presentation/profile_screen.dart',
    ).readAsStringSync();

    expect(source, contains('user.isAnonymous'));
    expect(source, contains('建立帳戶保存進度'));
    expect(source, contains('_buildAuthForm(isUpgrade: true)'));
  });

  test('signed-in profile exposes a protected account deletion boundary', () {
    final source = File(
      'lib/features/profile/presentation/profile_screen.dart',
    ).readAsStringSync();
    final config =
        File('lib/core/config/public_app_config.dart').readAsStringSync();

    expect(source, contains('delete-account'));
    expect(source, contains('clearCurrentAccountData'));
    expect(source, contains('刪除帳戶'));
    expect(config, contains('FISHERGO_ACCOUNT_DELETION_ENABLED'));
    expect(source, contains('PublicAppConfig.accountDeletionEnabled'));
    expect(source, contains('if (PublicAppConfig.accountDeletionEnabled)'));
  });

  test('profile exposes only owner-configured privacy and support links', () {
    final source = File(
      'lib/features/profile/presentation/profile_screen.dart',
    ).readAsStringSync();

    expect(source, contains('_buildLegalSupportPanel'));
    expect(source, contains('PublicAppConfig.privacyPolicyUrl'));
    expect(source, contains('PublicAppConfig.supportEmail'));
    expect(source, contains('launchUrl'));
    expect(source, contains('LaunchMode.externalApplication'));
  });

  test(
    'profile exposes a support-based report flow without inventing contact data',
    () {
      final source = File(
        'lib/features/profile/presentation/profile_screen.dart',
      ).readAsStringSync();

      expect(source, contains('報告問題'));
      expect(source, contains('PublicAppConfig.problemReportUri'));
      expect(source, contains('把問題位置和描述寄給支援團隊'));
    },
  );

  test('email upgrade restores the local account namespace immediately', () {
    final source = File(
      'lib/features/profile/presentation/profile_screen.dart',
    ).readAsStringSync();
    final upgradeIndex = source.indexOf('await auth.updateUser(');
    final restoreIndex = source.indexOf(
      'await LocalAccountService.restoreSession();',
      upgradeIndex,
    );

    expect(upgradeIndex, greaterThanOrEqualTo(0));
    expect(restoreIndex, greaterThan(upgradeIndex));
  });

  test('Google upgrade uses the platform-safe identity linker', () {
    final source = File(
      'lib/features/profile/presentation/profile_screen.dart',
    ).readAsStringSync();

    expect(source, contains('final launched = await auth.linkIdentity('));
    expect(source, contains('AuthRedirectConfig.oauthRedirect'));
    expect(source, contains('if (!launched)'));
    expect(source, isNot(contains('setBrowserLocationHref(response.url)')));
  });

  test('startup Google sign-in uses the shared platform callback', () {
    final source = File(
      'lib/features/game_home/presentation/game_home_screen.dart',
    ).readAsStringSync();

    expect(source, contains('AuthRedirectConfig.oauthRedirect'));
    expect(source, isNot(contains("redirectTo: 'https://fisher-go.app'")));
  });

  test('Android manifest accepts the native auth callback', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, contains('android.intent.action.VIEW'));
    expect(manifest, contains('android.intent.category.BROWSABLE'));
    expect(manifest, contains('android:scheme="fishergo"'));
    expect(manifest, contains('android:host="auth"'));
    expect(manifest, contains('android:pathPrefix="/callback"'));
  });
}
