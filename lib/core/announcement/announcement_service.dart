import 'package:hive/hive.dart';

/// Tracks whether today's announcement has been seen and coins claimed.
class AnnouncementService {
  static const String _boxName = 'announcement_box';
  static const String _keyLastSeen =
      'last_announcement_seen_date'; // YYYY-MM-DD
  static const String _keyClaimedDate =
      'announcement_claimed_date'; // YYYY-MM-DD

  static Box? _openedBox;

  static Future<Box> get _box async {
    if (_openedBox != null && _openedBox!.isOpen) return _openedBox!;
    _openedBox = await Hive.openBox(_boxName);
    return _openedBox!;
  }

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
