import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:fishergo/main.dart' as app;
import 'package:fishergo/features/profile/data/player_progress_service.dart';

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
    'notification opt-in waits for the first catch and can be deferred',
    (tester) async {
      await Hive.initFlutter();
      await Hive.deleteBoxFromDisk('startup_gate');
      await Hive.deleteBoxFromDisk('tutorial_box');
      await Hive.deleteBoxFromDisk('anonymous.profile_customization');
      await Hive.deleteBoxFromDisk('anonymous.notification_preferences');

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

      expect(find.text('釣點及活動提醒'), findsNothing);

      await PlayerProgressService.saveStateForTest(
        PlayerProgressState.empty.copyWith(totalCatches: 1),
      );
      await tester.tap(find.text('帳戶'));
      await _pumpUntil(
        tester,
        find.text('個人資料'),
        timeout: const Duration(seconds: 15),
      );
      await _pumpUntil(
        tester,
        find.text('釣點及活動提醒'),
        timeout: const Duration(seconds: 15),
      );
      expect(find.text('開啟通知'), findsOneWidget);

      await tester.tap(find.text('稍後'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('釣點及活動提醒'), findsNothing);
    },
  );
}
