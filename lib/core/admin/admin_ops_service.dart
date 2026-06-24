import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/profile/data/profile_wallet_service.dart';
import '../config/supabase_config.dart';

class AdminOpsService {
  const AdminOpsService._();

  static SupabaseClient get _client => Supabase.instance.client;

  static bool get _ready => SupabaseConfig.isConfigured;

  static Future<bool> isCurrentUserAdmin() async {
    if (!_ready || _client.auth.currentSession == null) return false;
    try {
      final result = await _client.rpc('is_admin');
      return result == true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> createAnnouncement({
    required String title,
    required String body,
    required int coinReward,
    DateTime? endsAt,
  }) async {
    await _client.from('admin_announcements').insert({
      'title': title,
      'body': body,
      'coin_reward': coinReward,
      'ends_at': endsAt?.toIso8601String(),
      'created_by': _client.auth.currentUser?.id,
    });
  }

  static Future<void> createEvent({
    required String title,
    required String description,
    required String fishName,
    required double multiplier,
    DateTime? endsAt,
  }) async {
    final event = await _client
        .from('admin_events')
        .insert({
          'title': title,
          'description': description,
          'ends_at': endsAt?.toIso8601String(),
          'created_by': _client.auth.currentUser?.id,
        })
        .select('id')
        .single();

    await _client.from('fish_rate_boosts').insert({
      'event_id': event['id'],
      'fish_name': fishName,
      'multiplier': multiplier,
      'ends_at': endsAt?.toIso8601String(),
      'created_by': _client.auth.currentUser?.id,
    });
  }

  static Future<void> grantCoins({
    required int amount,
    required String reason,
    String? targetEmail,
  }) async {
    await _client.from('coin_grants').insert({
      'target_email': targetEmail?.trim().isEmpty == true ? null : targetEmail,
      'amount': amount,
      'reason': reason,
      'created_by': _client.auth.currentUser?.id,
    });
  }

  static Future<Map<String, double>> activeFishBoosts() async {
    if (!_ready || _client.auth.currentSession == null) return const {};
    try {
      final rows = await _client
          .from('fish_rate_boosts')
          .select('fish_name,multiplier')
          .lte('starts_at', DateTime.now().toIso8601String())
          .or('ends_at.is.null,ends_at.gte.${DateTime.now().toIso8601String()}');
      final boosts = <String, double>{};
      for (final row in (rows as List)) {
        final name = row['fish_name']?.toString().trim();
        final multiplier = (row['multiplier'] as num?)?.toDouble();
        if (name != null && name.isNotEmpty && multiplier != null) {
          boosts[name] = (boosts[name] ?? 1.0) * multiplier;
        }
      }
      return boosts;
    } catch (_) {
      return const {};
    }
  }

  static Future<int> claimPendingCoinGrants() async {
    if (!_ready || _client.auth.currentSession == null) return 0;
    try {
      final result = await _client.rpc('claim_my_coin_grants');
      final amount = (result as num?)?.toInt() ?? 0;
      if (amount > 0) {
        await ProfileWalletService.addCoins(amount, reason: 'Admin 派發金幣');
      }
      return amount;
    } catch (_) {
      return 0;
    }
  }
}
