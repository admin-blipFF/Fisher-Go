import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/config/supabase_rpc_errors.dart';

/// Cloud-first player profile sync service.
/// Reads from Supabase; writes to both Supabase (primary) and Hive (cache).
class PlayerProfileSyncService {
  const PlayerProfileSyncService._();

  static SupabaseClient? get _client =>
      SupabaseConfig.isConfigured ? Supabase.instance.client : null;

  static PlayerProfile _defaultProfile(String userId) => PlayerProfile(
        userId: userId,
        coins: 500,
        avatarName: '默認角色',
        avatarColor: '#4A90E2',
        equippedRod: '木竿',
        equippedBait: '紅蟲',
        equippedHat: '無',
        equippedVest: '無',
        equippedBoat: '無',
      );

  /// Loads player's cloud profile. Falls back to default if not yet created.
  static Future<PlayerProfile> load(String userId) async {
    if (_client == null) return _defaultProfile(userId);
    try {
      final res = await _client!
          .from('player_profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      if (res != null) {
        return PlayerProfile.fromMap(Map<String, dynamic>.from(res));
      }
      // No cloud record yet — return defaults (caller should migrate)
      return _defaultProfile(userId);
    } catch (e) {
      return _defaultProfile(userId);
    }
  }

  /// Saves or creates player's profile to cloud.
  /// Returns true on success.
  static Future<bool> save(PlayerProfile profile) async {
    if (_client == null) return false;
    try {
      await _client!.from('player_profiles').upsert({
        'user_id': profile.userId,
        'coins': profile.coins,
        'total_coins_earned': profile.totalCoinsEarned,
        'avatar_name': profile.avatarName,
        'avatar_color': profile.avatarColor,
        'equipped_rod': profile.equippedRod,
        'equipped_bait': profile.equippedBait,
        'equipped_hat': profile.equippedHat,
        'equipped_vest': profile.equippedVest,
        'equipped_boat': profile.equippedBoat,
      }, onConflict: 'user_id');
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Adds coins to player's account. Returns updated coin count, or -1 on failure.
  static Future<int> addCoins(
    String userId,
    int amount, {
    String reason = 'client_reward',
    String rewardKind = 'virtual_catch',
    String? claimKey,
    String? fishId,
    String? gameplaySessionId,
    String? idempotencyKey,
  }) async {
    if (amount <= 0) return -1;
    if (_client != null) {
      try {
        final result = await _client!.rpc(
          'claim_gameplay_reward_ticket',
          params: {
            'p_reward_kind': rewardKind,
            'p_requested_amount': amount,
            'p_claim_key': claimKey ?? idempotencyKey ?? _newClaimKey(reason),
            'p_fish_id': fishId,
            'p_gameplay_session_id': gameplaySessionId,
          },
        );
        final map = result is Map
            ? Map<String, dynamic>.from(result)
            : const <String, dynamic>{};
        final balance = (map['balance'] as num?)?.toInt();
        return balance ?? -1;
      } catch (error) {
        // Keep rollout compatible with projects before migration 0016. A
        // session-bound reward must never fall back to a generic ticket.
        if (!_isMissingWalletRpc(error, 'claim_gameplay_reward_ticket')) {
          return -1;
        }
        if (gameplaySessionId != null) return -1;

        try {
          final legacyResult = await _client!.rpc(
            'claim_gameplay_reward_ticket',
            params: {
              'p_reward_kind': rewardKind,
              'p_requested_amount': amount,
              'p_claim_key': claimKey ?? idempotencyKey ?? _newClaimKey(reason),
              'p_fish_id': fishId,
            },
          );
          final legacyMap = legacyResult is Map
              ? Map<String, dynamic>.from(legacyResult)
              : const <String, dynamic>{};
          final legacyBalance = (legacyMap['balance'] as num?)?.toInt();
          if (legacyBalance != null) return legacyBalance;
        } catch (legacyError) {
          if (!_isMissingWalletRpc(
            legacyError,
            'claim_gameplay_reward_ticket',
          )) {
            return -1;
          }
        }

        final adjusted = await _adjustCoinsWithRpc(
          amount,
          reason: reason,
          idempotencyKey: idempotencyKey ?? claimKey,
        );
        if (adjusted != null) return adjusted;
      }
    }

    // Temporary migration fallback. Remove after 0014 is applied everywhere.
    final profile = await load(userId);
    final updated = profile.copyWith(
      coins: profile.coins + amount,
      totalCoinsEarned: profile.totalCoinsEarned + (amount > 0 ? amount : 0),
    );
    final saved = await save(updated);
    if (!saved) return -1;
    return updated.coins;
  }

  static Future<int?> _adjustCoinsWithRpc(
    int amount, {
    required String reason,
    String? idempotencyKey,
  }) async {
    try {
      final result = await _client!.rpc(
        'adjust_player_coins',
        params: {
          'p_amount': amount,
          'p_reason': reason,
          'p_idempotency_key': idempotencyKey,
        },
      );
      return (result as num?)?.toInt();
    } catch (error) {
      if (!_isMissingWalletRpc(error, 'adjust_player_coins')) return -1;
      return null;
    }
  }

  static String _newClaimKey(String reason) =>
      '$reason:${DateTime.now().toUtc().microsecondsSinceEpoch}';

  /// Deducts coins. Returns updated coin count, or -1 on failure (insufficient).
  static Future<int> deductCoins(
    String userId,
    int amount, {
    String? idempotencyKey,
  }) async {
    if (amount <= 0) return -1;
    if (_client != null) {
      try {
        final result = await _client!.rpc(
          'spend_player_coins',
          params: {
            'p_amount': amount,
            'p_idempotency_key': idempotencyKey,
          },
        );
        final balance = (result as num?)?.toInt();
        return balance ?? -1;
      } catch (error) {
        // Keep rollout compatible with projects before migration 0014. Any
        // other server error must fail closed instead of mutating the balance.
        if (!_isMissingWalletRpc(error, 'spend_player_coins')) return -1;
      }
    }

    // Temporary migration fallback. Remove after 0014 is applied everywhere.
    final profile = await load(userId);
    if (profile.coins < amount) return -1;
    final updated = profile.copyWith(coins: profile.coins - amount);
    final saved = await save(updated);
    if (!saved) return -1;
    return updated.coins;
  }

  static bool _isMissingWalletRpc(Object error, String functionName) {
    return isMissingSupabaseRpc(error, functionName);
  }
}

/// In-memory profile model for player_profiles table.
class PlayerProfile {
  final String userId;
  final int coins;
  final int totalCoinsEarned;
  final String avatarName;
  final String avatarColor;
  final String equippedRod;
  final String equippedBait;
  final String equippedHat;
  final String equippedVest;
  final String equippedBoat;

  const PlayerProfile({
    required this.userId,
    this.coins = 500,
    this.totalCoinsEarned = 0,
    this.avatarName = '默認角色',
    this.avatarColor = '#4A90E2',
    this.equippedRod = '木竿',
    this.equippedBait = '紅蟲',
    this.equippedHat = '無',
    this.equippedVest = '無',
    this.equippedBoat = '無',
  });

  factory PlayerProfile.fromMap(Map<String, dynamic> m) {
    return PlayerProfile(
      userId: m['user_id'] as String? ?? '',
      coins: (m['coins'] as num?)?.toInt() ?? 500,
      totalCoinsEarned: (m['total_coins_earned'] as num?)?.toInt() ?? 0,
      avatarName: m['avatar_name'] as String? ?? '默認角色',
      avatarColor: m['avatar_color'] as String? ?? '#4A90E2',
      equippedRod: m['equipped_rod'] as String? ?? '木竿',
      equippedBait: m['equipped_bait'] as String? ?? '紅蟲',
      equippedHat: m['equipped_hat'] as String? ?? '無',
      equippedVest: m['equipped_vest'] as String? ?? '無',
      equippedBoat: m['equipped_boat'] as String? ?? '無',
    );
  }

  PlayerProfile copyWith({
    String? userId,
    int? coins,
    int? totalCoinsEarned,
    String? avatarName,
    String? avatarColor,
    String? equippedRod,
    String? equippedBait,
    String? equippedHat,
    String? equippedVest,
    String? equippedBoat,
  }) {
    return PlayerProfile(
      userId: userId ?? this.userId,
      coins: coins ?? this.coins,
      totalCoinsEarned: totalCoinsEarned ?? this.totalCoinsEarned,
      avatarName: avatarName ?? this.avatarName,
      avatarColor: avatarColor ?? this.avatarColor,
      equippedRod: equippedRod ?? this.equippedRod,
      equippedBait: equippedBait ?? this.equippedBait,
      equippedHat: equippedHat ?? this.equippedHat,
      equippedVest: equippedVest ?? this.equippedVest,
      equippedBoat: equippedBoat ?? this.equippedBoat,
    );
  }

  Map<String, dynamic> toMap() => {
        'user_id': userId,
        'coins': coins,
        'total_coins_earned': totalCoinsEarned,
        'avatar_name': avatarName,
        'avatar_color': avatarColor,
        'equipped_rod': equippedRod,
        'equipped_bait': equippedBait,
        'equipped_hat': equippedHat,
        'equipped_vest': equippedVest,
        'equipped_boat': equippedBoat,
      };
}
