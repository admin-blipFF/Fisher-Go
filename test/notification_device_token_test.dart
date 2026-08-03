import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:fishergo/core/notifications/notification_device_token.dart';
import 'package:fishergo/core/notifications/notification_permission_service.dart';
import 'package:fishergo/core/notifications/notification_token_registration_service.dart';

void main() {
  test('normalizes a valid provider token for the registration RPC', () {
    const token = NotificationDeviceToken(
      platform: 'android',
      provider: 'fcm',
      token: '  provider-token-1234567890  ',
    );

    expect(token.isValid, isTrue);
    expect(token.toRpcParams(), <String, Object?>{
      'p_platform': 'android',
      'p_provider': 'fcm',
      'p_token': 'provider-token-1234567890',
    });
  });

  test('rejects unsupported platforms, providers, and empty tokens', () {
    expect(
      const NotificationDeviceToken(
        platform: 'desktop',
        provider: 'fcm',
        token: 'provider-token-1234567890',
      ).isValid,
      isFalse,
    );
    expect(
      const NotificationDeviceToken(
        platform: 'android',
        provider: 'unknown',
        token: 'provider-token-1234567890',
      ).isValid,
      isFalse,
    );
    expect(
      const NotificationDeviceToken(
        platform: 'android',
        provider: 'fcm',
        token: '   ',
      ).isValid,
      isFalse,
    );
  });

  test('registers and unregisters a token through the RPC boundary', () async {
    final calls = <String>[];
    final service = NotificationTokenRegistrationService(
      invoke: (method, params) async {
        calls.add('$method:${params['p_token']}');
        return method == 'register_notification_device_token'
            ? 'token-row-id'
            : true;
      },
    );
    const token = NotificationDeviceToken(
      platform: 'ios',
      provider: 'apns',
      token: 'provider-token-1234567890',
    );

    final registration = await service.register(token);
    final removed = await service.unregister(token);

    expect(registration.status, NotificationRegistrationStatus.registered);
    expect(registration.remoteId, 'token-row-id');
    expect(removed, isTrue);
    expect(calls, <String>[
      'register_notification_device_token:provider-token-1234567890',
      'unregister_notification_device_token:provider-token-1234567890',
    ]);
  });

  test('skips registration when a provider has not supplied a token', () async {
    var invoked = false;
    final service = NotificationTokenRegistrationService(
      invoke: (method, params) async {
        invoked = true;
        return null;
      },
    );

    final result = await service.register(null);

    expect(result.status, NotificationRegistrationStatus.skipped);
    expect(invoked, isFalse);
  });

  test('permission bridge parses a provider token without exposing secrets',
      () async {
    final permission = NotificationPermissionService(
      invoke: (method) async {
        if (method != 'deviceToken') return null;
        return <String, Object?>{
          'platform': 'android',
          'provider': 'fcm',
          'token': 'provider-token-1234567890',
        };
      },
    );

    final token = await permission.deviceToken();

    expect(token?.platform, 'android');
    expect(token?.provider, 'fcm');
    expect(token?.token, 'provider-token-1234567890');
  });

  test('notification token boundary is wired into the protected release', () {
    final migration = File(
      'supabase/migrations/0027_notification_device_tokens.sql',
    ).readAsStringSync().toLowerCase();
    final shape = File(
      'supabase/tests/notification_device_tokens_shape_test.sql',
    ).readAsStringSync().toLowerCase();
    final workflow = File(
      '.github/workflows/supabase-content-release.yml',
    ).readAsStringSync();
    final profile = File(
      'lib/features/profile/presentation/profile_screen.dart',
    ).readAsStringSync();

    expect(migration, contains('player_notification_tokens'));
    expect(migration, contains('register_notification_device_token'));
    expect(migration, contains('unregister_notification_device_token'));
    expect(migration, contains('enable row level security'));
    expect(shape, contains('notification token table is private'));
    expect(shape, contains('anonymous cannot register notification tokens'));
    expect(workflow, contains('notification_device_tokens_shape_test.sql'));
    expect(profile, contains('NotificationTokenRegistrationService'));
    expect(profile, contains('deviceToken()'));
  });
}
