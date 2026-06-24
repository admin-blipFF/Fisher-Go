import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';

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
  static Future<int> addCoins(String userId, int amount) async {
    final profile = await load(userId);
    final updated = profile.copyWith(
      coins: profile.coins + amount,
      totalCoinsEarned: profile.totalCoinsEarned + (amount > 0 ? amount : 0),
    );
    final saved = await save(updated);
    if (!saved) return -1;
    return updated.coins;
  }

  /// Deducts coins. Returns updated coin count, or -1 on failure (insufficient).
  static Future<int> deductCoins(String userId, int amount) async {
    final profile = await load(userId);
    if (profile.coins < amount) return -1;
    final updated = profile.copyWith(coins: profile.coins - amount);
    final saved = await save(updated);
    if (!saved) return -1;
    return updated.coins;
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
