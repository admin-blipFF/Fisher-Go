import 'package:hive/hive.dart';

class TutorialService {
  static const String _boxName = 'tutorial_box';
  static const String _keyCompletedPrefix = 'tutorial_completed:';
  static const String _legacyKeyCompleted = 'tutorial_completed';

  static Future<Box> get _box async => Hive.openBox(_boxName);

  /// Returns true if tutorial already completed
  static Future<bool> isCompleted({String identityKey = 'local'}) async {
    final box = await _box;
    final current = box.get(_keyFor(identityKey));
    if (current is bool) return current;
    if (identityKey == 'local') {
      return box.get(_legacyKeyCompleted, defaultValue: false) == true;
    }
    return false;
  }

  /// Mark tutorial as done
  static Future<void> markCompleted({String identityKey = 'local'}) async {
    final box = await _box;
    await box.put(_keyFor(identityKey), true);
  }

  /// Reset tutorial state (for testing/debug)
  static Future<void> reset({String identityKey = 'local'}) async {
    final box = await _box;
    await box.put(_keyFor(identityKey), false);
    if (identityKey == 'local') {
      await box.put(_legacyKeyCompleted, false);
    }
  }

  static String _keyFor(String identityKey) =>
      '$_keyCompletedPrefix${identityKey.trim().isEmpty ? 'local' : identityKey}';
}
