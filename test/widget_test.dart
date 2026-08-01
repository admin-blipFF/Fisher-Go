import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:fishergo/main.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir =
        await Directory.systemTemp.createTemp('fishergo_widget_hive_test_');
    Hive.init(tempDir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  testWidgets('FisherGO web encyclopedia renders sample fish cards',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    await tester.pumpWidget(const FisherGoApp());
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(seconds: 3));

    expect(find.text('Fisher Lv. 1'), findsOneWidget);
    expect(find.textContaining('探索水域'), findsOneWidget);
    expect(find.textContaining('附近'), findsOneWidget);
    expect(find.text('圖鑑'), findsOneWidget);
    expect(find.text('裝備'), findsOneWidget);
    expect(find.text('上魚獲'), findsOneWidget);
    expect(find.text('排行'), findsOneWidget);
    expect(find.byTooltip('全景地圖'), findsOneWidget);

    await tester.tap(find.byTooltip('全景地圖'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('全景地圖'), findsOneWidget);
  });

  testWidgets('encyclopedia cards stay clear of the return map control',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(411, 900));
    await tester.pumpWidget(const FisherGoApp());
    await tester.pump(const Duration(seconds: 3));

    await tester.tap(find.text('圖鑑').last);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 3));

    final mapControl = find.byKey(const ValueKey('return-map-control'));
    expect(mapControl, findsOneWidget);
    final mapControlRect = tester.getRect(mapControl);
    // Collection state may be populated by an earlier test in the same
    // isolate, so layout coverage must not depend on every card being locked.
    final catalogNumbers = find.byWidgetPredicate(
      (widget) =>
          widget is Text && RegExp(r'^#\d{3}$').hasMatch(widget.data ?? ''),
    );
    expect(catalogNumbers, findsWidgets);
    final catalogCards = find.ancestor(
      of: catalogNumbers,
      matching: find.byType(Card),
    );
    expect(catalogCards, findsWidgets);
    final catalogScrollables = find.ancestor(
      of: catalogNumbers,
      matching: find.byType(Scrollable),
    );
    expect(catalogScrollables, findsWidgets);
    final viewportRect = tester.getRect(catalogScrollables.first);

    for (var index = 0;
        index < tester.widgetList(catalogCards).length;
        index++) {
      final cardRect = tester.getRect(catalogCards.at(index));
      final visibleCardRect = cardRect.intersect(viewportRect);
      if (visibleCardRect.isEmpty) continue;
      final overlaps = visibleCardRect.overlaps(mapControlRect);
      expect(overlaps, isFalse,
          reason: 'catalog card $index is covered by the return map control');
    }
  });
}
