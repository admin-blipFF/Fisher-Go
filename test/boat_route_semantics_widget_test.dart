import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:latlong2/latlong.dart';

import 'package:fishergo/domain/boat_vendor.dart';
import 'package:fishergo/features/boat/presentation/boat_route_screen.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'fishergo_boat_route_semantics_test_',
    );
    Hive.init(tempDir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  testWidgets('boat route exposes progress, spot state, and fishing action',
      (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      const vendor = BoatVendor(
        id: 'semantics-vendor',
        name: '測試船家',
        zoneName: '測試水域',
        dialogues: [],
        priceCoins: 0,
        spotNames: ['測試碼頭'],
        spotLocations: [LatLng(22.3, 114.1)],
      );

      await tester.pumpWidget(
        const MaterialApp(home: BoatRouteScreen(vendor: vendor)),
      );
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel('船線 測試船家，測試水域，已完成 0/1 個釣點，進行中'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('釣點 測試碼頭，可作釣，按作釣開始釣魚'),
        findsOneWidget,
      );
      expect(find.text('作釣'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });
}
