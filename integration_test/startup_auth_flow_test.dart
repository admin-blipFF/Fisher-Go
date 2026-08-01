import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:fishergo/main.dart' as app;

Future<void> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  required Duration timeout,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure(
    'Timed out waiting for ${finder.describeMatch(Plurality.many)}.',
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'fresh startup requires identity, then allows tutorial skip into GameHome',
    (tester) async {
      await Hive.initFlutter();
      await Hive.deleteBoxFromDisk('startup_gate');
      await Hive.deleteBoxFromDisk('tutorial_box');

      app.main();
      await _pumpUntil(
        tester,
        find.text('開始 FisherGO'),
        timeout: const Duration(seconds: 60),
      );

      expect(find.text('開始 FisherGO'), findsOneWidget);
      expect(find.text('訪客遊玩'), findsOneWidget);

      await tester.tap(find.text('訪客遊玩'));
      await _pumpUntil(
        tester,
        find.text('你好！歡迎來到 FisherGO！'),
        timeout: const Duration(seconds: 20),
      );

      expect(find.text('你好！歡迎來到 FisherGO！'), findsOneWidget);
      expect(find.text('略過'), findsOneWidget);

      await tester.tap(find.text('略過'));
      await _pumpUntil(
        tester,
        find.bySemanticsLabel('Fisher Lv. 1'),
        timeout: const Duration(seconds: 45),
      );

      expect(find.bySemanticsLabel('Fisher Lv. 1'), findsOneWidget);
      expect(find.bySemanticsLabel('全景地圖'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('旋轉地圖，方向 0 度'));
      await _pumpUntil(
        tester,
        find.bySemanticsLabel('旋轉地圖，方向 45 度'),
        timeout: const Duration(seconds: 5),
      );
      expect(find.bySemanticsLabel('旋轉地圖，方向 45 度'), findsOneWidget);

      await tester.tap(find.text('圖鑑'));
      await _pumpUntil(
        tester,
        find.text('全部'),
        timeout: const Duration(seconds: 15),
      );
      expect(find.text('香港魚類圖鑑'), findsOneWidget);
      expect(find.text('全部'), findsOneWidget);
      expect(find.textContaining('已解鎖'), findsOneWidget);
      expect(find.text('未發現'), findsWidgets);
    },
  );
}
