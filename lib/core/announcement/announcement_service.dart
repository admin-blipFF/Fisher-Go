import 'package:hive/hive.dart';

import '../auth/local_account_service.dart';

/// Tracks whether today's announcement has been seen and coins claimed.
class AnnouncementService {
  static const String _boxBaseName = 'announcement_box';
  static const String _keyLastSeen =
      'last_announcement_seen_date'; // YYYY-MM-DD
  static const String _keyClaimedDate =
      'announcement_claimed_date'; // YYYY-MM-DD

  static final Map<String, Box<dynamic>> _openedBoxes = {};

  static Future<Box> get _box async {
    final accountId = LocalAccountService.currentAccountId ??
        LocalAccountService.guestAccountId;
    final boxName = boxNameForAccount(accountId);
    final opened = _openedBoxes[boxName];
    if (opened != null && opened.isOpen) return opened;
    final box = await Hive.openBox<dynamic>(boxName);
    _openedBoxes[boxName] = box;
    return box;
  }

  /// Returns the Hive box used for an account's announcement state.
  ///
  /// Keeping this deterministic lets account deletion remove only the
  /// deleted player's claim state when multiple accounts share a device.
  static String boxNameForAccount(String accountId) =>
      LocalAccountService.boxNameFor(_boxBaseName, accountId);

  /// Returns true if user has NOT yet seen today's announcement.
  static Future<bool> hasUnseen() async {
    final box = await _box;
    final last = box.get(_keyLastSeen, defaultValue: '') as String;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return last != today;
  }

  /// Mark today's announcement as seen.
  static Future<void> markSeen() async {
    final box = await _box;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    await box.put(_keyLastSeen, today);
  }

  /// Returns true if today's announcement coin reward has been claimed.
  static Future<bool> hasClaimedToday() async {
    final box = await _box;
    final claimed = box.get(_keyClaimedDate, defaultValue: '') as String;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return claimed == today;
  }

  /// Mark today's announcement coin reward as claimed.
  static Future<void> markClaimed() async {
    final box = await _box;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    await box.put(_keyClaimedDate, today);
  }

  /// Reset (for testing).
  static Future<void> reset() async {
    final box = await _box;
    await box.delete(_keyLastSeen);
    await box.delete(_keyClaimedDate);
  }
}
