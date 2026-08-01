import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:fishergo/core/notifications/notification_opt_in.dart';

void main() {
  late Directory tempDir;
  late NotificationPreferenceStore store;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('fishergo_notifications_');
    Hive.init(tempDir.path);
  });

  setUp(() async {
    store = NotificationPreferenceStore(
      boxName: 'notification_test_${DateTime.now().microsecondsSinceEpoch}',
    );
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('notification prompt waits until the player has caught a fish', () {
    expect(
      NotificationOptInPolicy.shouldPrompt(
        totalCatches: 0,
        preference: const NotificationPreference.undecided(),
        now: DateTime(2026, 8, 1),
      ),
      isFalse,
    );
    expect(
      NotificationOptInPolicy.shouldPrompt(
        totalCatches: 1,
        preference: const NotificationPreference.undecided(),
        now: DateTime(2026, 8, 1),
      ),
      isTrue,
    );
  });

  test('deferred prompts wait seven days and declined prompts stay quiet', () {
    final deferred = NotificationPreference.deferredAt(DateTime(2026, 8, 1));
    expect(
      NotificationOptInPolicy.shouldPrompt(
        totalCatches: 1,
        preference: deferred,
        now: DateTime(2026, 8, 7, 23),
      ),
      isFalse,
    );
    expect(
      NotificationOptInPolicy.shouldPrompt(
        totalCatches: 1,
        preference: deferred,
        now: DateTime(2026, 8, 8),
      ),
      isTrue,
    );
    expect(
      NotificationOptInPolicy.shouldPrompt(
        totalCatches: 1,
        preference: const NotificationPreference.declined(),
        now: DateTime(2026, 8, 8),
      ),
      isFalse,
    );
  });

  test('preference store persists the user decision', () async {
    expect((await store.load()).choice, NotificationOptInChoice.undecided);
    await store.defer(DateTime(2026, 8, 1));
    expect((await store.load()).choice, NotificationOptInChoice.deferred);
    expect((await store.load()).deferredAt, DateTime(2026, 8, 1));
    await store.setEnabled();
    expect((await store.load()).choice, NotificationOptInChoice.enabled);
  });
}
