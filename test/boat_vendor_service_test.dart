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
      'default.boat_vendor',
      'local_accounts',
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

    final markerBox = await Hive.openBox('local_accounts');
    await markerBox.delete('boat_vendor_legacy_migrated');
    await markerBox.close();
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

  test('boat state is stored in the current account namespace', () async {
    final namespaced = await Hive.openBox('default.boat_vendor');
    await namespaced.put('avatar_state', {'active_boat_vendor_id': '4sea'});
    await namespaced.close();

    expect(await BoatVendorService.getActiveVendorId(), '4sea');
    expect(Hive.isBoxOpen('boat_vendor_box'), isFalse);
  });

  test('legacy boat state is copied once into the account namespace', () async {
    final legacy = await Hive.openBox('boat_vendor_box');
    await legacy.put('avatar_state', {'active_boat_vendor_id': 'island'});
    await legacy.close();

    expect(await BoatVendorService.getActiveVendorId(), 'island');

    final target = await Hive.openBox('default.boat_vendor');
    expect(
      (target.get('avatar_state') as Map)['active_boat_vendor_id'],
      'island',
    );
    await target.close();
  });

  test('boat spot result preserves success and failure states', () async {
    expect(await BoatVendorService.getBoatSpotResult('4sea', 0), isNull);

    expect(
      await BoatVendorService.recordBoatSpotAttempt('4sea', 0, 'success'),
      isTrue,
    );
    expect(await BoatVendorService.getBoatSpotResult('4sea', 0), 'success');
    expect(await BoatVendorService.hasBoatSpotAttempted('4sea', 0), isTrue);

    expect(
      await BoatVendorService.recordBoatSpotAttempt('4sea', 0, 'fail'),
      isFalse,
    );
    expect(await BoatVendorService.getBoatSpotResult('4sea', 0), 'success');
  });
}
