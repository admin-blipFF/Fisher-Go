import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Syncs local account namespace with Supabase Auth session.
///
/// For cloud-first data (coins, fish collection, profile):
/// → use PlayerProfileSyncService / FishCollectionSyncService
/// For local/non-critical state (announcements, tutorial):
/// → use Hive via this service with Supabase user_id prefix.
class LocalAccountService {
  static const _boxName = 'local_accounts';
  static const _keyCurrent = 'current_account_id';

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

  static final Future<Box> _box = Hive.openBox(_boxName);

  /// Syncs local session with Supabase auth session.
  /// Should be called on app startup after Supabase session is restored.
  static Future<void> restoreSession() async {
    final userId = supabaseUserId;
    _currentAccountId = userId ?? 'anonymous';
  }

  /// Returns the current account ID (Supabase UUID or 'anonymous').
  static Future<String?> getCurrentAccountId() async {
    await restoreSession();
    return _currentAccountId;
  }

  static Future<void> signOut() async {
    _currentAccountId = null;
    try {
      final box = await _box;
      await box.delete(_keyCurrent);
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
}
