import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Syncs local account namespace with Supabase Auth session.
///
/// For cloud-first data (coins, fish collection, profile):
/// → use PlayerProfileSyncService / FishCollectionSyncService
/// For local/non-critical state (announcements, tutorial):
/// → use Hive via this service with an account-scoped namespace.
class LocalAccountService {
  static const _boxName = 'local_accounts';
  static const _keyCurrent = 'current_account_id';
  static const _keyGuestMigrationTarget = 'guest_migration_target';
  static const guestAccountId = 'anonymous';
  static const _accountBoxBases = <String>[
    'profile_customization',
    'fish_collection',
    'boat_vendor',
    'catch_queue',
    'notification_preferences',
    'announcement_box',
  ];

  /// In-memory cache of the current account ID.
  static String? _currentAccountId;
  static String? get currentAccountId => _currentAccountId;

  /// Returns the Supabase user ID (UUID) for the current session, or null.
  static String? get supabaseUserId {
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  static Future<Box> get _box async {
    if (Hive.isBoxOpen(_boxName)) return Hive.box<dynamic>(_boxName);
    return Hive.openBox(_boxName);
  }

  /// Syncs local session with Supabase auth session.
  /// Should be called on app startup after Supabase session is restored.
  static Future<void> restoreSession() async {
    final userId = supabaseUserId;
    if (userId == null) {
      _currentAccountId = guestAccountId;
      return;
    }

    await migrateGuestDataToAccount(userId);
    _currentAccountId = userId;
  }

  /// Returns the current account ID (Supabase UUID or 'anonymous').
  static Future<String?> getCurrentAccountId() async {
    await restoreSession();
    return _currentAccountId;
  }

  static Future<void> signOut() async {
    _currentAccountId = guestAccountId;
    try {
      final box = await _box;
      await box.delete(_keyCurrent);
    } catch (_) {}
  }

  /// Removes the local namespace for the account that was just deleted.
  ///
  /// This deliberately does not touch the shared guest namespace: a player
  /// may continue locally as a new guest after deleting a cloud account.
  static Future<void> clearCurrentAccountData() async {
    final accountId = _currentAccountId ?? supabaseUserId;
    if (accountId == null || accountId == guestAccountId) return;
    await clearAccountDataFor(accountId);
  }

  /// Testable/account-scoped variant used by the account deletion boundary.
  static Future<void> clearAccountDataFor(String accountId) async {
    final id = accountId.trim();
    if (id.isEmpty || id == guestAccountId) return;

    for (final baseName in _accountBoxBases) {
      final boxName = boxNameFor(baseName, id);
      if (Hive.isBoxOpen(boxName)) {
        await Hive.box<dynamic>(boxName).close();
      }
      await Hive.deleteBoxFromDisk(boxName);
    }

    // These legacy caches predate account-scoped Hive boxes. Remove only the
    // deleted user's entry while preserving other accounts on this device.
    try {
      final fishCache = Hive.isBoxOpen('fish_collection_cloud')
          ? Hive.box<dynamic>('fish_collection_cloud')
          : await Hive.openBox<dynamic>('fish_collection_cloud');
      await fishCache.delete(id);
    } catch (_) {}
    try {
      final tutorial = Hive.isBoxOpen('tutorial_box')
          ? Hive.box<dynamic>('tutorial_box')
          : await Hive.openBox<dynamic>('tutorial_box');
      await tutorial.delete('tutorial_completed:$id');
    } catch (_) {}

    _currentAccountId = guestAccountId;
    try {
      final accountBox = await _box;
      await accountBox.delete(_keyCurrent);
      await accountBox.delete(_keyGuestMigrationTarget);
    } catch (_) {}
  }

  /// Hive key prefix for account-isolated storage.
  /// Uses Supabase user ID when signed in; 'anonymous.' otherwise.
  static String accountPrefix([String? accountId]) {
    final id = accountId ?? _currentAccountId;
    return id != null ? '$id.' : 'default.';
  }

  static String boxNameFor(String baseName, [String? accountId]) {
    return '${accountPrefix(accountId)}$baseName';
  }

  static String get profileBoxName => '${accountPrefix()}profile_customization';

  static String get fishCollectionBoxName =>
      '${accountPrefix()}fish_collection';

  static String get catchQueueBoxName => boxNameFor('catch_queue');

  /// Moves the local guest cache into the first account created on this device.
  ///
  /// The migration is deliberately one-shot. Keeping the source cache avoids
  /// data loss if email confirmation is still pending, while the marker stops
  /// a later, unrelated account from receiving the guest's private data.
  static Future<void> migrateGuestDataToAccount(String userId) async {
    final targetId = userId.trim();
    if (targetId.isEmpty || targetId == guestAccountId) return;

    final accountBox = await _box;
    final previousTarget = accountBox.get(_keyGuestMigrationTarget);
    if (previousTarget is String && previousTarget != targetId) return;
    if (previousTarget == targetId) return;

    await _mergeBox(
      boxNameFor('profile_customization', guestAccountId),
      boxNameFor('profile_customization', targetId),
    );
    await _mergeBox(
      boxNameFor('fish_collection', guestAccountId),
      boxNameFor('fish_collection', targetId),
    );
    await _mergeBox(
      boxNameFor('boat_vendor', guestAccountId),
      boxNameFor('boat_vendor', targetId),
    );
    await _mergeBox(
      boxNameFor('announcement_box', guestAccountId),
      boxNameFor('announcement_box', targetId),
    );
    await _mergeBox(
      boxNameFor('catch_queue', guestAccountId),
      boxNameFor('catch_queue', targetId),
      mergeItems: true,
    );
    // Versions before account scoping used this global queue name.
    await _mergeBox(
      'catch_queue',
      boxNameFor('catch_queue', targetId),
      mergeItems: true,
    );

    await accountBox.put(_keyGuestMigrationTarget, targetId);
  }

  static Future<void> _mergeBox(
    String sourceName,
    String targetName, {
    bool mergeItems = false,
  }) async {
    if (sourceName == targetName) return;
    final source = await Hive.openBox<dynamic>(sourceName);
    final target = await Hive.openBox<dynamic>(targetName);

    for (final key in source.keys) {
      final sourceValue = source.get(key);
      if (!target.containsKey(key)) {
        await target.put(key, sourceValue);
        continue;
      }

      if (key == 'avatar_state' &&
          sourceValue is Map &&
          target.get(key) is Map) {
        final merged = Map<String, dynamic>.from(
          Map<dynamic, dynamic>.from(target.get(key) as Map),
        )..addAll(Map<String, dynamic>.from(sourceValue));
        await target.put(key, merged);
      } else if (sourceValue is Map && target.get(key) is Map) {
        final merged = Map<dynamic, dynamic>.from(
          target.get(key) as Map,
        )..addAll(Map<dynamic, dynamic>.from(sourceValue));
        await target.put(key, merged);
      } else if (mergeItems && key == 'items') {
        final existing = target.get(key);
        if (sourceValue is List && existing is List) {
          final existingIds = existing
              .whereType<Map>()
              .map((item) => item['id'])
              .whereType<String>()
              .toSet();
          final additions = sourceValue
              .whereType<Map>()
              .where((item) => !existingIds.contains(item['id']))
              .toList(growable: false);
          if (additions.isNotEmpty) {
            await target.put('items', [...additions, ...existing]);
          }
        }
      }
    }
  }
}
