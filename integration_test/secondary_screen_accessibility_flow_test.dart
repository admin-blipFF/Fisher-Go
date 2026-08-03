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

Future<void> _returnToMap(WidgetTester tester) async {
  final returnButton = find.bySemanticsLabel('返回地圖');
  expect(returnButton, findsOneWidget);
  await tester.tap(returnButton);
  await _pumpUntil(
    tester,
    find.bySemanticsLabel('Fisher Lv. 1'),
    timeout: const Duration(seconds: 15),
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'secondary screens expose semantics navigation and return to the map',
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

      await tester.tap(find.text('訪客遊玩'));
      await _pumpUntil(
        tester,
        find.text('你好！歡迎來到 FisherGO！'),
        timeout: const Duration(seconds: 20),
      );
      await tester.tap(find.text('略過'));
      await _pumpUntil(
        tester,
        find.bySemanticsLabel('Fisher Lv. 1'),
        timeout: const Duration(seconds: 45),
      );

      final screens = <({
        String entryLabel,
        Finder title,
        Finder stableContent,
      })>[
        (
          entryLabel: '帳戶',
          title: find.text('個人資料'),
          stableContent: find.text('今日任務'),
        ),
        (
          entryLabel: '圖鑑',
          title: find.text('香港魚類圖鑑'),
          stableContent: find.text('全部'),
        ),
        (
          entryLabel: '上魚獲',
          title: find.text('魚獲記錄（離線佇列）'),
          stableContent: find.bySemanticsLabel('選擇魚獲相片'),
        ),
        (
          entryLabel: '排行',
          title: find.text('比賽活動'),
          stableContent: find.bySemanticsLabel(
            RegExp(r'^真實捕獲排行榜，共 \d+ 項$'),
          ),
        ),
      ];

      for (final screen in screens) {
        final entry = find.bySemanticsLabel(screen.entryLabel);
        expect(entry, findsOneWidget,
            reason: 'Missing semantics entry: ${screen.entryLabel}');
        await tester.tap(entry);
        await _pumpUntil(
          tester,
          screen.title,
          timeout: const Duration(seconds: 20),
        );
        expect(screen.title, findsOneWidget);
        await _pumpUntil(
          tester,
          screen.stableContent,
          timeout: const Duration(seconds: 20),
        );
        expect(screen.stableContent, findsOneWidget,
            reason: 'Missing stable content on ${screen.entryLabel}');
        await _returnToMap(tester);
      }
    },
  );
}
