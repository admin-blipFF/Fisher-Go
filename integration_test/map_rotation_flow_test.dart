import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:integration_test/integration_test.dart';

import 'package:fishergo/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('GameHome rotation control advances the MapLibre bearing',
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

    final initialRotation = find.bySemanticsLabel('旋轉地圖，方向 0 度');
    expect(initialRotation, findsOneWidget);

    await tester.tap(initialRotation);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.bySemanticsLabel('旋轉地圖，方向 45 度'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('旋轉地圖，方向 45 度'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.bySemanticsLabel('旋轉地圖，方向 90 度'), findsOneWidget);
  });
}
