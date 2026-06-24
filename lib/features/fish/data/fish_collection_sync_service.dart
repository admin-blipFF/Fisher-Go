import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';

/// Manages which fish IDs the current user has collected.
/// Cloud-first: reads from Supabase, writes to Supabase + Hive cache.
class FishCollectionSyncService {
  const FishCollectionSyncService._();

  static SupabaseClient? get _client =>
      SupabaseConfig.isConfigured ? Supabase.instance.client : null;

  static const String _hiveBoxName = 'fish_collection_cloud';

  /// Loads all fish IDs collected by the user from Supabase.
  /// Returns empty set if not configured or error.
  static Future<Set<String>> loadCollectedIds(String userId) async {
    if (_client == null) return {};
    try {
      final res = await _client!
          .from('player_fish_collections')
          .select('fish_id')
          .eq('user_id', userId);
      return res.map((r) => r['fish_id'] as String).toSet();
    } catch (_) {
      return {};
    }
  }

  /// Records that the user caught a fish. Upserts to Supabase.
  /// Returns true on success.
  static Future<bool> recordCatch({
    required String userId,
    required String fishId,
    required int rarity,
    double? weightGrams,
  }) async {
    if (_client == null) return false;
    try {
      // Check if already exists
      final existing = await _client!
          .from('player_fish_collections')
          .select('id,catch_count,best_weight_grams')
          .eq('user_id', userId)
          .eq('fish_id', fishId)
          .maybeSingle();

      if (existing != null) {
        // Increment count, update best weight if better
        final current = Map<String, dynamic>.from(existing);
        final count = (current['catch_count'] as int? ?? 1) + 1;
        final best = current['best_weight_grams'] as double?;
        final newBest =
            (best == null || (weightGrams ?? 0) > best) ? weightGrams : best;

        await _client!
            .from('player_fish_collections')
            .update({
              'catch_count': count,
              'best_weight_grams': newBest,
              'best_rarity': rarity,
            })
            .eq('user_id', userId)
            .eq('fish_id', fishId);
      } else {
        // New fish!
        await _client!.from('player_fish_collections').insert({
          'user_id': userId,
          'fish_id': fishId,
          'first_caught_at': DateTime.now().toIso8601String(),
          'catch_count': 1,
          'best_weight_grams': weightGrams,
          'best_rarity': rarity,
        });
      }

      // Also update local Hive cache
      await _updateLocalCache(userId, fishId);
      return true;
    } catch (_) {
      // Also try local cache
      await _updateLocalCache(userId, fishId);
      return false;
    }
  }

  /// Checks if a fish has been collected.
  static Future<bool> hasCollected(String userId, String fishId) async {
    if (_client == null) return false;
    try {
      final res = await _client!
          .from('player_fish_collections')
          .select('id')
          .eq('user_id', userId)
          .eq('fish_id', fishId)
          .maybeSingle();
      return res != null;
    } catch (_) {
      // Fallback to local cache
      return _hasLocal(fishId);
    }
  }

  /// Gets total count of collected fish species.
  static Future<int> getTotalCollected(String userId) async {
    final ids = await loadCollectedIds(userId);
    return ids.length;
  }

  // --- Local Hive cache helpers ---

  static Future<void> _updateLocalCache(String userId, String fishId) async {
    try {
      final box = await Hive.openBox(_hiveBoxName);
      final existing = box.get(userId, defaultValue: <String>[]) as List;
      final list = Set<String>.from(existing);
      list.add(fishId);
      await box.put(userId, list.toList());
    } catch (_) {}
  }

  static Future<bool> _hasLocal(String fishId) async {
    try {
      // We need userId here — use a global fallback cache
      final box = await Hive.openBox(_hiveBoxName);
      final userId = _currentUserId ?? 'default';
      final raw = box.get(userId, defaultValue: <String>[]);
      return (raw as List).contains(fishId);
    } catch (_) {
      return false;
    }
  }

  static String? _currentUserId;
  static void setCurrentUserId(String? id) => _currentUserId = id;
}
