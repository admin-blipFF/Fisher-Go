import 'package:hive/hive.dart';

class TutorialService {
  static const String _boxName = 'tutorial_box';
  static const String _keyCompleted = 'tutorial_completed';

  static Future<Box> get _box async => Hive.openBox(_boxName);

  /// Returns true if tutorial already completed
  static Future<bool> isCompleted() async {
    final box = await _box;
    return box.get(_keyCompleted, defaultValue: false);
  }

  /// Mark tutorial as done
  static Future<void> markCompleted() async {
    final box = await _box;
    await box.put(_keyCompleted, true);
  }

  /// Reset tutorial state (for testing/debug)
  static Future<void> reset() async {
    final box = await _box;
    await box.put(_keyCompleted, false);
  }
}
