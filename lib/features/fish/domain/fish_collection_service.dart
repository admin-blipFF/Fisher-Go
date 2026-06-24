import 'package:hive/hive.dart';

import '../../../core/auth/local_account_service.dart';
import '../data/fish_collection_sync_service.dart';
import 'fish_collection_status.dart';

/// Cloud-first fish collection service.
/// Primary data: Supabase player_fish_collections
/// Local cache: Hive (for offline support and fast loading)
class FishCollectionService {
  static String get boxName => LocalAccountService.fishCollectionBoxName;

  /// Loads all collected fish entries.
  /// Priority: Hive cache (fast) → Supabase (authoritative) → empty
  static Future<Map<String, PlayerFishCollectionEntry>> loadAll() async {
    final userId = LocalAccountService.supabaseUserId;
    final localEntries = await _loadFromHive();

    // Try Supabase first
    if (userId != null) {
      try {
        final cloudIds =
            await FishCollectionSyncService.loadCollectedIds(userId);
        final result = _mergeCloudCaughtIds(localEntries, cloudIds);
        // Also sync to Hive for offline use
        await _syncToHive(result.keys.toSet());
        if (result.isNotEmpty) return result;
      } catch (_) {}
    }

    return localEntries;
  }

  static Future<Map<String, PlayerFishCollectionEntry>> _loadFromHive() async {
    final result = <String, PlayerFishCollectionEntry>{};
    // Fallback to Hive
    try {
      final box = await Hive.openBox(boxName);
      for (final key in box.keys) {
        final raw = box.get(key);
        if (raw is Map) {
          final entry = PlayerFishCollectionEntry.fromMap(raw);
          result[entry.fishId] = entry;
        }
      }
    } catch (_) {}

    return result;
  }

  static Map<String, PlayerFishCollectionEntry> _mergeCloudCaughtIds(
    Map<String, PlayerFishCollectionEntry> localEntries,
    Set<String> cloudIds,
  ) {
    final result = Map<String, PlayerFishCollectionEntry>.from(localEntries);
    for (final id in cloudIds) {
      final existing = result[id];
      if (existing == null) {
        result[id] = PlayerFishCollectionEntry(
          fishId: id,
          status: FishDiscoveryStatus.gameCaught,
          firstGameCaughtAt: DateTime.now(),
        );
        continue;
      }
      result[id] = existing.copyWith(
        status: FishDiscoveryStatus.gameCaught.index > existing.status.index
            ? FishDiscoveryStatus.gameCaught
            : existing.status,
        firstGameCaughtAt: existing.firstGameCaughtAt ?? DateTime.now(),
      );
    }
    return result;
  }

  static Map<String, PlayerFishCollectionEntry> mergeCloudCaughtIdsForTest(
    Map<String, PlayerFishCollectionEntry> localEntries,
    Set<String> cloudIds,
  ) =>
      _mergeCloudCaughtIds(localEntries, cloudIds);

  static Future<Map<String, PlayerFishCollectionEntry>> loadAllSafe() async {
    try {
      return await loadAll().timeout(const Duration(seconds: 3));
    } catch (_) {
      return const <String, PlayerFishCollectionEntry>{};
    }
  }

  static Future<PlayerFishCollectionEntry?> getEntry(String fishId) async {
    final box = await Hive.openBox(boxName);
    final raw = box.get(fishId);
    if (raw is Map) return PlayerFishCollectionEntry.fromMap(raw);
    return null;
  }

  static Future<PlayerFishCollectionEntry> markEncountered(
      String fishId) async {
    return _promote(fishId, FishDiscoveryStatus.encountered);
  }

  static Future<PlayerFishCollectionEntry> markGameCaught(String fishId) async {
    return _promote(fishId, FishDiscoveryStatus.gameCaught);
  }

  static Future<PlayerFishCollectionEntry> markVerifiedRealCatch(
    String fishId, {
    String? photoPath,
    double? bestLengthCm,
    double? latitude,
    double? longitude,
  }) async {
    return _promote(
      fishId,
      FishDiscoveryStatus.verifiedRealCatch,
      photoPath: photoPath,
      bestLengthCm: bestLengthCm,
      latitude: latitude,
      longitude: longitude,
    );
  }

  static Future<PlayerFishCollectionEntry> _promote(
    String fishId,
    FishDiscoveryStatus target, {
    String? photoPath,
    double? bestLengthCm,
    double? latitude,
    double? longitude,
  }) async {
    final box = await Hive.openBox(boxName);
    final existingRaw = box.get(fishId);
    final existing = existingRaw is Map
        ? PlayerFishCollectionEntry.fromMap(existingRaw)
        : PlayerFishCollectionEntry(
            fishId: fishId,
            status: FishDiscoveryStatus.unknown,
          );

    final now = DateTime.now();
    final promotedStatus = _higher(existing.status, target);
    final updated = existing.copyWith(
      status: promotedStatus,
      firstEncounteredAt: existing.firstEncounteredAt ?? now,
      firstGameCaughtAt: target.index >= FishDiscoveryStatus.gameCaught.index
          ? existing.firstGameCaughtAt ?? now
          : existing.firstGameCaughtAt,
      firstRealCaughtAt: target == FishDiscoveryStatus.verifiedRealCatch
          ? existing.firstRealCaughtAt ?? now
          : existing.firstRealCaughtAt,
      realCatchPhotoPath: photoPath,
      bestLengthCm: bestLengthCm,
      catchLatitude: latitude,
      catchLongitude: longitude,
    );

    // Write to Hive cache
    await box.put(fishId, updated.toMap());

    // Write to Supabase (if signed in)
    final userId = LocalAccountService.supabaseUserId;
    if (userId != null) {
      // Fire-and-forget to cloud (non-blocking)
      FishCollectionSyncService.recordCatch(
        userId: userId,
        fishId: fishId,
        rarity: 1, // Default rarity; override if known
      );
    }

    return updated;
  }

  static FishDiscoveryStatus _higher(
    FishDiscoveryStatus current,
    FishDiscoveryStatus next,
  ) {
    return next.index > current.index ? next : current;
  }

  static Future<void> _syncToHive(Set<String> fishIds) async {
    try {
      final box = await Hive.openBox(boxName);
      for (final id in fishIds) {
        if (!box.containsKey(id)) {
          final raw = PlayerFishCollectionEntry(
            fishId: id,
            status: FishDiscoveryStatus.gameCaught,
            firstGameCaughtAt: DateTime.now(),
          );
          await box.put(id, raw.toMap());
        }
      }
    } catch (_) {}
  }
}
