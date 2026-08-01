import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android declares notification permission and method-channel bridge',
      () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final activity = File(
      'android/app/src/main/kotlin/com/fishergo/app/MainActivity.kt',
    ).readAsStringSync();

    expect(manifest, contains('android.permission.POST_NOTIFICATIONS'));
    expect(activity, contains('fishergo/notifications'));
    expect(activity, contains('requestNotifications'));
    expect(activity, contains('openNotificationSettings'));
    expect(activity, contains('ACTION_APP_NOTIFICATION_SETTINGS'));
    expect(activity, contains('EXTRA_APP_PACKAGE'));
    expect(activity, contains('onRequestPermissionsResult'));
  });

  test('profile only offers notification opt-in after a catch', () {
    final source = File('lib/features/profile/presentation/profile_screen.dart')
        .readAsStringSync();

    expect(source, contains('NotificationOptInPolicy'));
    expect(source, contains('_buildNotificationOptInPanel'));
    expect(source, contains('_progressState.totalCatches'));
    expect(source, contains('完成首個釣獲後'));
    expect(source, contains('_buildNotificationSettingsPanel'));
    expect(source, contains('_openNotificationSettings'));
    expect(source, contains('didChangeAppLifecycleState'));
  });
}
