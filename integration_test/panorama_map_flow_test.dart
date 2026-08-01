import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:integration_test/integration_test.dart';
import 'package:maplibre/maplibre.dart';

import 'package:fishergo/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('panorama opens the production MapLibre surface', (tester) async {
    await Hive.initFlutter();
    await Hive.deleteBoxFromDisk('startup_gate');
    await Hive.deleteBoxFromDisk('tutorial_box');

    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await tester.tap(find.text('訪客遊玩'));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await tester.tap(find.text('略過'));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    await tester.tap(find.bySemanticsLabel('全景地圖'));
    await tester.pumpAndSettle(const Duration(seconds: 4));

    expect(find.text('全景地圖'), findsOneWidget);
    expect(find.text('拖動畫面找釣點，點選圖標查看詳情'), findsOneWidget);
    expect(find.byType(MapLibreMap), findsWidgets);

    await tester.tap(find.bySemanticsLabel('關閉全景地圖'));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.bySemanticsLabel('全景地圖'), findsOneWidget);
  });
}
