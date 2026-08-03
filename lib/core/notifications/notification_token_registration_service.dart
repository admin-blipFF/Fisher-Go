import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import 'notification_device_token.dart';

typedef NotificationRpcInvoker = Future<Object?> Function(
  String method,
  Map<String, Object?> params,
);

enum NotificationRegistrationStatus { registered, skipped, failed }

class NotificationRegistrationResult {
  const NotificationRegistrationResult({
    required this.status,
    this.remoteId,
  });

  const NotificationRegistrationResult.skipped()
      : status = NotificationRegistrationStatus.skipped,
        remoteId = null;

  const NotificationRegistrationResult.failed()
      : status = NotificationRegistrationStatus.failed,
        remoteId = null;

  final NotificationRegistrationStatus status;
  final String? remoteId;
}

/// Best-effort registration for a token supplied by a platform push provider.
/// Permission state and provider delivery are deliberately separate concerns.
class NotificationTokenRegistrationService {
  NotificationTokenRegistrationService({NotificationRpcInvoker? invoke})
      : _invoke = invoke;

  final NotificationRpcInvoker? _invoke;

  NotificationRpcInvoker? get _resolvedInvoker {
    if (_invoke != null) return _invoke;
    if (!SupabaseConfig.isConfigured) return null;
    try {
      final client = Supabase.instance.client;
      return (method, params) => client.rpc(method, params: params);
    } catch (_) {
      return null;
    }
  }

  Future<NotificationRegistrationResult> register(
    NotificationDeviceToken? token,
  ) async {
    if (token == null || !token.isValid) {
      return const NotificationRegistrationResult.skipped();
    }
    final invoke = _resolvedInvoker;
    if (invoke == null) return const NotificationRegistrationResult.skipped();

    try {
      final raw = await invoke(
        'register_notification_device_token',
        token.toRpcParams(),
      );
      return NotificationRegistrationResult(
        status: NotificationRegistrationStatus.registered,
        remoteId: raw?.toString(),
      );
    } catch (_) {
      return const NotificationRegistrationResult.failed();
    }
  }

  Future<bool> unregister(NotificationDeviceToken? token) async {
    if (token == null || !token.isValid) return false;
    final invoke = _resolvedInvoker;
    if (invoke == null) return false;
    try {
      final raw = await invoke(
        'unregister_notification_device_token',
        <String, Object?>{
          'p_provider': token.normalizedProvider,
          'p_token': token.normalizedToken,
        },
      );
      return raw == true || raw == 'true';
    } catch (_) {
      return false;
    }
  }
}
