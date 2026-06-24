import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:fishergo/core/shop/boat_vendor_service.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir =
        await Directory.systemTemp.createTemp('fishergo_boat_vendor_test_');
    Hive.init(tempDir.path);
  });

  setUp(() async {
    for (final boxName in [
      'boat_vendor_box',
      'default.profile_customization',
    ]) {
      if (Hive.isBoxOpen(boxName)) {
        await Hive.box<dynamic>(boxName).clear();
        await Hive.box<dynamic>(boxName).close();
      }
    }
    final profileBox = await Hive.openBox('default.profile_customization');
    await profileBox.put('avatar_state', {'coins': 0});
    await profileBox.close();
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('rent fails and does not activate vendor when coins are insufficient',
      () async {
    final rented = await BoatVendorService.rent('4sea');

    expect(rented, isFalse);
    expect(await BoatVendorService.getActiveVendorId(), isNull);
  });
}
