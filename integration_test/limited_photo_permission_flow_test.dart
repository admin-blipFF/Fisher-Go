import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:integration_test/integration_test.dart';

import 'package:fishergo/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'selected-photo access keeps the catch-photo entry usable',
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

      await tester.tap(find.text('上魚獲'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.text('魚獲記錄（離線佇列）'), findsOneWidget);
      expect(find.text('選擇相片'), findsOneWidget);
      expect(find.text('點擊拍照或選擇相片'), findsOneWidget);
    },
  );
}
