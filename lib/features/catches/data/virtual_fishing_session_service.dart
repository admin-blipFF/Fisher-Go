import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/config/supabase_rpc_errors.dart';

/// Server-issued timing state for one virtual fishing attempt.
class VirtualFishingSession {
  const VirtualFishingSession({
    required this.sessionId,
    required this.fishId,
    required this.biteDelayMs,
    required this.successWindowMs,
  });

  final String sessionId;
  final String fishId;
  final int biteDelayMs;
  final int successWindowMs;

  factory VirtualFishingSession.fromMap(Map<String, dynamic> map) {
    final sessionId = map['session_id']?.toString().trim() ?? '';
    final fishId = map['fish_id']?.toString().trim() ?? '';
    if (sessionId.isEmpty || fishId.isEmpty) {
      throw const FormatException('invalid virtual fishing session');
    }
    return VirtualFishingSession(
      sessionId: sessionId,
      fishId: fishId,
      biteDelayMs: (map['bite_delay_ms'] as num?)?.toInt() ?? 1600,
      successWindowMs: (map['success_window_ms'] as num?)?.toInt() ?? 900,
    );
  }
}

class VirtualFishingResolution {
  const VirtualFishingResolution({
    required this.sessionId,
    required this.success,
    required this.status,
  });

  final String sessionId;
  final bool success;
  final String status;

  factory VirtualFishingResolution.fromMap(Map<String, dynamic> map) {
    final sessionId = map['session_id']?.toString().trim() ?? '';
    if (sessionId.isEmpty) {
      throw const FormatException('invalid virtual fishing resolution');
    }
    return VirtualFishingResolution(
      sessionId: sessionId,
      success: map['success'] == true,
      status: map['status']?.toString() ?? 'resolved_miss',
    );
  }
}

/// Thin RPC boundary for server-validated bite timing.
class VirtualFishingSessionService {
  const VirtualFishingSessionService._();

  static SupabaseClient? get _client =>
      SupabaseConfig.isConfigured ? Supabase.instance.client : null;

  /// Returns null only when the linked project has not applied 0020 yet.
  /// Other server failures are surfaced so callers do not silently grant a
  /// reward after a partially deployed security boundary.
  static Future<VirtualFishingSession?> start({
    required String spotId,
    required String lureId,
    required String fishId,
    required double? latitude,
    required double? longitude,
    required double? accuracyMeters,
  }) async {
    final client = _client;
    if (client == null || client.auth.currentSession == null) return null;

    try {
      final raw = await client.rpc(
        'start_virtual_fishing_session',
        params: {
          'p_spot_id': spotId,
          'p_lure_id': lureId,
          'p_fish_id': fishId,
          'p_player_latitude': latitude,
          'p_player_longitude': longitude,
          'p_accuracy_m': accuracyMeters,
        },
      );
      return VirtualFishingSession.fromMap(_asMap(raw));
    } catch (error) {
      if (_isMissingRpc(error, 'start_virtual_fishing_session')) return null;
      rethrow;
    }
  }

  static Future<VirtualFishingResolution?> resolve({
    required String sessionId,
    required int pullElapsedMs,
  }) async {
    final client = _client;
    if (client == null || client.auth.currentSession == null) return null;

    try {
      final raw = await client.rpc(
        'resolve_virtual_fishing_session',
        params: {
          'p_session_id': sessionId,
          'p_pull_elapsed_ms': pullElapsedMs,
        },
      );
      return VirtualFishingResolution.fromMap(_asMap(raw));
    } catch (error) {
      if (_isMissingRpc(error, 'resolve_virtual_fishing_session')) return null;
      rethrow;
    }
  }

  static Map<String, dynamic> _asMap(Object? value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const FormatException('invalid virtual fishing RPC response');
  }

  static bool _isMissingRpc(Object error, String functionName) {
    return isMissingSupabaseRpc(error, functionName);
  }
}
