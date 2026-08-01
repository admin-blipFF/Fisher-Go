import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:fishergo/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'disabled location service keeps the GPS-free map usable',
    (tester) async {
      await Hive.initFlutter();
      await Hive.deleteBoxFromDisk('startup_gate');
      await Hive.deleteBoxFromDisk('tutorial_box');

      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      await tester.tap(find.text('訪客遊玩'));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      await tester.tap(find.text('略過'));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text('重新定位'), findsOneWidget);
      await tester.tap(find.text('重新定位'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.text('請先開啟手機定位服務。'), findsOneWidget);
      expect(find.bySemanticsLabel('全景地圖'), findsOneWidget);
    },
  );
}
