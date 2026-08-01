import 'package:hive/hive.dart';

import '../auth/local_account_service.dart';

enum NotificationOptInChoice { undecided, enabled, declined, deferred }

class NotificationPreference {
  const NotificationPreference({
    this.choice = NotificationOptInChoice.undecided,
    this.deferredAt,
  });

  const NotificationPreference.undecided()
      : choice = NotificationOptInChoice.undecided,
        deferredAt = null;

  const NotificationPreference.enabled()
      : choice = NotificationOptInChoice.enabled,
        deferredAt = null;

  const NotificationPreference.declined()
      : choice = NotificationOptInChoice.declined,
        deferredAt = null;

  NotificationPreference.deferredAt(DateTime value)
      : choice = NotificationOptInChoice.deferred,
        deferredAt = value;

  final NotificationOptInChoice choice;
  final DateTime? deferredAt;
}

class NotificationOptInPolicy {
  const NotificationOptInPolicy._();

  static const _deferDuration = Duration(days: 7);

  static bool shouldPrompt({
    required int totalCatches,
    required NotificationPreference preference,
    required DateTime now,
  }) {
    if (totalCatches < 1) return false;
    switch (preference.choice) {
      case NotificationOptInChoice.enabled:
      case NotificationOptInChoice.declined:
        return false;
      case NotificationOptInChoice.undecided:
        return true;
      case NotificationOptInChoice.deferred:
        final deferredAt = preference.deferredAt;
        return deferredAt == null ||
            !now.isBefore(deferredAt.add(_deferDuration));
    }
  }
}

class NotificationPreferenceStore {
  NotificationPreferenceStore({String? boxName}) : _boxName = boxName;

  static const _defaultBaseName = 'notification_preferences';
  static const _choiceKey = 'choice';
  static const _deferredAtKey = 'deferred_at';

  final String? _boxName;

  Future<Box<dynamic>> get _box async => Hive.openBox<dynamic>(
        _boxName ?? LocalAccountService.boxNameFor(_defaultBaseName),
      );

  Future<NotificationPreference> load() async {
    final box = await _box;
    final rawChoice = box.get(_choiceKey);
    final choice = NotificationOptInChoice.values.firstWhere(
      (value) => value.name == rawChoice,
      orElse: () => NotificationOptInChoice.undecided,
    );
    final rawDeferredAt = box.get(_deferredAtKey);
    final parsedDeferredAt = rawDeferredAt is String
        ? DateTime.tryParse(rawDeferredAt)?.toLocal()
        : null;
    return NotificationPreference(
      choice: choice,
      deferredAt: parsedDeferredAt,
    );
  }

  Future<void> setEnabled() async {
    final box = await _box;
    await box.put(_choiceKey, NotificationOptInChoice.enabled.name);
    await box.delete(_deferredAtKey);
  }

  Future<void> setDeclined() async {
    final box = await _box;
    await box.put(_choiceKey, NotificationOptInChoice.declined.name);
    await box.delete(_deferredAtKey);
  }

  Future<void> defer(DateTime now) async {
    final box = await _box;
    await box.put(_choiceKey, NotificationOptInChoice.deferred.name);
    await box.put(_deferredAtKey, now.toUtc().toIso8601String());
  }
}
