import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:fishergo/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'tutorial enters the bite-first fishing minigame on API 35',
    (tester) async {
      Future<void> pumpFor(Duration duration) async {
        const step = Duration(milliseconds: 100);
        var remaining = duration;
        while (remaining > Duration.zero) {
          final slice = remaining < step ? remaining : step;
          await tester.pump(slice);
          remaining -= slice;
        }
      }

      await Hive.initFlutter();
      await Hive.deleteBoxFromDisk('startup_gate');
      await Hive.deleteBoxFromDisk('tutorial_box');

      app.main();
      await pumpFor(const Duration(seconds: 2));

      expect(find.text('開始 FisherGO'), findsOneWidget);
      await tester.tap(find.text('訪客遊玩'));
      await pumpFor(const Duration(seconds: 2));

      expect(find.text('你好！歡迎來到 FisherGO！'), findsOneWidget);
      await tester.tap(find.text('下一步'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('下一步'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('開始釣魚 (教學)'), findsOneWidget);
      await tester.tap(find.text('開始釣魚 (教學)'));

      // The tutorial uses a deterministic 0.8 second wait before the bite.
      // Pump in animation-sized slices; a single long pump advances only one
      // test frame and would skip the controller's 50 ms bite ticks.
      var biteReady = false;
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        if (find.text('魚食餌！').evaluate().isNotEmpty) {
          biteReady = true;
          break;
        }
      }

      expect(biteReady, isTrue);
      expect(find.text('魚食餌！'), findsOneWidget);
      expect(find.text('浮標急震，立即抽竿'), findsOneWidget);
      expect(find.text('抽竿！'), findsOneWidget);

      await tester.tap(find.text('抽竿！'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('收線'), findsOneWidget);

      // fish-010 is the deterministic tutorial catch. Short pull/release
      // cycles keep tension in the stamina-drain band while bringing the line
      // home, then the revealed result can be inspected.
      final pullPoint = tester.getCenter(find.text('收線'));
      var caught = false;
      for (var cycle = 0; cycle < 60; cycle++) {
        final pull = await tester.startGesture(pullPoint);
        for (var tick = 0; tick < 10; tick++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        await pull.up();
        for (var tick = 0; tick < 10; tick++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        if (find.textContaining('成功上鉤！').evaluate().isNotEmpty) {
          caught = true;
          break;
        }
      }

      expect(caught, isTrue);
      await tester.pump(const Duration(milliseconds: 1200));
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName ==
                  'assets/fish/mobile_webp/010.webp',
        ),
        findsOneWidget,
      );
    },
  );
}
