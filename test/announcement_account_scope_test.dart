import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:fishergo/core/announcement/announcement_service.dart';
import 'package:fishergo/core/auth/local_account_service.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('fishergo_announcement_');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    for (final name in [
      'anonymous.announcement_box',
      'user-123.announcement_box',
      'announcement_box',
    ]) {
      await Hive.deleteBoxFromDisk(name);
    }
  });

  tearDownAll(() async {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('announcement claim state is scoped to the current guest account',
      () async {
    await LocalAccountService.restoreSession();

    await AnnouncementService.markClaimed();

    final accountBox =
        await Hive.openBox<dynamic>('anonymous.announcement_box');
    final legacyBox = await Hive.openBox<dynamic>('announcement_box');
    expect(accountBox.get('announcement_claimed_date'), isNotNull);
    expect(legacyBox.get('announcement_claimed_date'), isNull);
  });

  test('guest announcement state migrates to the upgraded account', () async {
    await LocalAccountService.restoreSession();
    await AnnouncementService.markClaimed();

    await LocalAccountService.migrateGuestDataToAccount('user-123');

    final accountBox = await Hive.openBox<dynamic>('user-123.announcement_box');
    expect(accountBox.get('announcement_claimed_date'), isNotNull);
  });
}
