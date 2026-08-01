import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:integration_test/integration_test.dart';

import 'package:fishergo/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'GPS-centered verified spot remains selectable after rotation',
    (tester) async {
      await Hive.initFlutter();
      await Hive.deleteBoxFromDisk('startup_gate');
      await Hive.deleteBoxFromDisk('tutorial_box');

      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      await tester.tap(find.text('訪客遊玩'));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      await tester.tap(find.text('略過'));
      // The API 35 emulator may take several seconds to deliver a fresh
      // high-accuracy fix after `emu geo fix`.
      await tester.pumpAndSettle(const Duration(seconds: 7));

      final spotName = find.text('青衣公眾碼頭');
      expect(spotName, findsOneWidget);

      final initialRotation = find.bySemanticsLabel('旋轉地圖，方向 0 度');
      expect(initialRotation, findsOneWidget);
      await tester.tap(initialRotation);
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.bySemanticsLabel('旋轉地圖，方向 45 度'), findsOneWidget);
      await tester.tap(spotName, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('已到達釣點'), findsOneWidget);
    },
  );
}
