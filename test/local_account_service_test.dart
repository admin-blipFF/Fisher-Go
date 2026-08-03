import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:fishergo/core/auth/local_account_service.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('fishergo_account_test_');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    for (final name in [
      'local_accounts',
      'anonymous.profile_customization',
      'anonymous.fish_collection',
      'anonymous.catch_queue',
      'anonymous.boat_vendor',
      'catch_queue',
      'user-123.profile_customization',
      'user-123.fish_collection',
      'user-123.catch_queue',
      'user-123.boat_vendor',
      'user-123.announcement_box',
      'fish_collection_cloud',
      'tutorial_box',
      'user-first.profile_customization',
      'user-first.fish_collection',
      'user-first.catch_queue',
      'user-first.boat_vendor',
      'user-second.profile_customization',
      'user-second.fish_collection',
      'user-second.catch_queue',
      'user-second.boat_vendor',
    ]) {
      await Hive.deleteBoxFromDisk(name);
    }
  });

  tearDownAll(() async {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('guest upgrade migrates progress, collection, and legacy catch queue',
      () async {
    final profile =
        await Hive.openBox<dynamic>('anonymous.profile_customization');
    await profile.put('avatar_state', {
      'coins': 780,
      'ownedItemIds': ['rod_rare'],
    });
    await profile.put('player_progress_state', {
      'level': 4,
      'totalCatches': 7,
      'dailyTasksClaimed': ['catch_2_fish'],
    });

    final collection = await Hive.openBox<dynamic>('anonymous.fish_collection');
    await collection.put('fish-010', {
      'fishId': 'fish-010',
      'status': 2,
      'firstGameCaughtAt': '2026-07-19T08:00:00.000Z',
    });

    final legacyQueue = await Hive.openBox<dynamic>('catch_queue');
    await legacyQueue.put('items', [
      {'id': 'catch-1', 'speciesName': '烏頭'},
    ]);

    await LocalAccountService.migrateGuestDataToAccount('user-123');

    final migratedProfile =
        await Hive.openBox<dynamic>('user-123.profile_customization');
    final migratedCollection =
        await Hive.openBox<dynamic>('user-123.fish_collection');
    final migratedQueue = await Hive.openBox<dynamic>('user-123.catch_queue');

    expect((migratedProfile.get('avatar_state') as Map)['coins'], 780);
    expect((migratedProfile.get('player_progress_state') as Map)['level'], 4);
    expect(migratedCollection.get('fish-010'), isNotNull);
    expect((migratedQueue.get('items') as List).single['id'], 'catch-1');
  });

  test('guest data is not copied to a second account after migration',
      () async {
    final guest =
        await Hive.openBox<dynamic>('anonymous.profile_customization');
    await guest.put('avatar_state', {'coins': 900});
    final guestBoat = await Hive.openBox<dynamic>('anonymous.boat_vendor');
    await guestBoat.put('avatar_state', {
      'active_boat_vendor_id': '4sea',
    });

    await LocalAccountService.migrateGuestDataToAccount('user-first');
    await LocalAccountService.migrateGuestDataToAccount('user-second');

    final second =
        await Hive.openBox<dynamic>('user-second.profile_customization');
    expect(second.get('avatar_state'), isNull);
    final secondBoat = await Hive.openBox<dynamic>('user-second.boat_vendor');
    expect(secondBoat.get('avatar_state'), isNull);
  });

  test('guest upgrade migrates account-scoped boat route state', () async {
    final guestBoat = await Hive.openBox<dynamic>('anonymous.boat_vendor');
    await guestBoat.put('avatar_state', {
      'active_boat_vendor_id': '4sea',
    });
    await guestBoat.put('boat_spot_results_4sea', {'0': 'success'});

    final accountBoat = await Hive.openBox<dynamic>('user-123.boat_vendor');
    await accountBoat.put('boat_spot_results_4sea', {'1': 'fail'});

    await LocalAccountService.migrateGuestDataToAccount('user-123');

    final migrated = await Hive.openBox<dynamic>('user-123.boat_vendor');
    expect(
      (migrated.get('avatar_state') as Map)['active_boat_vendor_id'],
      '4sea',
    );
    expect(
      migrated.get('boat_spot_results_4sea'),
      {'0': 'success', '1': 'fail'},
    );
  });

  test('clearAccountDataFor removes the deleted account namespace', () async {
    final profile =
        await Hive.openBox<dynamic>('user-123.profile_customization');
    await profile.put('avatar_state', {'coins': 42});
    final catches = await Hive.openBox<dynamic>('user-123.catch_queue');
    await catches.put('items', [
      {'id': 'catch-123'},
    ]);

    await LocalAccountService.clearAccountDataFor('user-123');

    expect(
      Hive.isBoxOpen('user-123.profile_customization'),
      isFalse,
    );
    expect(
      Hive.isBoxOpen('user-123.catch_queue'),
      isFalse,
    );
    expect(
      File('${tempDir.path}/user-123.profile_customization.hive').existsSync(),
      isFalse,
    );
    expect(
      File('${tempDir.path}/user-123.catch_queue.hive').existsSync(),
      isFalse,
    );
  });

  test('clearAccountDataFor removes account-keyed caches and legacy markers',
      () async {
    final cloudCache = await Hive.openBox<dynamic>('fish_collection_cloud');
    await cloudCache.put('user-123', ['fish-010']);
    await cloudCache.put('user-456', ['fish-011']);
    final tutorial = await Hive.openBox<dynamic>('tutorial_box');
    await tutorial.put('tutorial_completed:user-123', true);
    final announcement =
        await Hive.openBox<dynamic>('user-123.announcement_box');
    await announcement.put('announcement_claimed_date', '2026-08-03');

    await LocalAccountService.clearAccountDataFor('user-123');

    expect(cloudCache.get('user-123'), isNull);
    expect(cloudCache.get('user-456'), ['fish-011']);
    expect(tutorial.get('tutorial_completed:user-123'), isNull);
    expect(
      File('${tempDir.path}/user-123.announcement_box.hive').existsSync(),
      isFalse,
    );
  });
}
