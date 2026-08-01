import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';

import 'package:fishergo/core/notifications/notification_permission_service.dart';

void main() {
  test('maps platform notification status and request results', () async {
    final calls = <String>[];
    final service = NotificationPermissionService(
      invoke: (method) async {
        calls.add(method);
        return method == 'request' ? true : 'granted';
      },
    );

    expect(
      await service.status(),
      NotificationPermissionStatus.granted,
    );
    expect(
      await service.request(),
      NotificationPermissionStatus.granted,
    );
    expect(calls, ['status', 'request']);
  });

  test('turns missing platform implementation into unavailable', () async {
    final service = NotificationPermissionService(
      invoke: (_) async => throw MissingPluginException(),
    );

    expect(await service.status(), NotificationPermissionStatus.unavailable);
    expect(await service.request(), NotificationPermissionStatus.unavailable);
  });

  test('opens the operating-system notification settings', () async {
    final service = NotificationPermissionService(
      invoke: (method) async => method == 'openSettings',
    );

    expect(await service.openSettings(), isTrue);
  });
}
