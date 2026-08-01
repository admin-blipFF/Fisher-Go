import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:fishergo/main.dart' as app;
import 'package:fishergo/core/auth/local_account_service.dart';
import 'package:fishergo/features/profile/data/player_progress_service.dart';
import 'package:fishergo/features/profile/data/profile_wallet_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'completed daily task can be claimed and persists in account state',
    (tester) async {
      await Hive.initFlutter();
      await Hive.deleteBoxFromDisk('startup_gate');
      await Hive.deleteBoxFromDisk('tutorial_box');
      await LocalAccountService.restoreSession();
      await Hive.deleteBoxFromDisk(LocalAccountService.profileBoxName);
      await PlayerProgressService.saveStateForTest(
        const PlayerProgressState(
          level: 1,
          xp: 40,
          totalCatches: 2,
          uniqueFishCaught: 1,
          currentStreakDays: 1,
          bestStreakDays: 1,
          dailyCatches: 2,
          dailyUniqueFish: 1,
          dailyTasksCompleted: {'catch_2_fish'},
          dailyTasksClaimed: {},
        ),
      );

      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      await tester.tap(find.text('訪客遊玩'));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      await tester.tap(find.text('略過'));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.bySemanticsLabel('Fisher Lv. 1'), findsOneWidget);
      expect(find.text('帳戶'), findsOneWidget);
      await tester.tap(find.text('帳戶'));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.text('今日任務'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, '+20'), findsOneWidget);
      expect(await ProfileWalletService.getCoins(), 500);

      await tester.tap(find.widgetWithText(FilledButton, '+20'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.text('已領'), findsOneWidget);
      expect(await ProfileWalletService.getCoins(), 520);
      final saved = await PlayerProgressService.loadState();
      expect(saved.dailyTasksClaimed, contains('catch_2_fish'));
    },
  );
}
