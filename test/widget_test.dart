import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive/hive.dart';

import 'package:fishergo/main.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir =
        await Directory.systemTemp.createTemp('fishergo_widget_hive_test_');
    Hive.init(tempDir.path);
    dotenv.loadFromString(
      envString: 'SUPABASE_URL=\nSUPABASE_ANON_KEY=\nVECTOR_ENGINE_API_KEY=\n',
    );
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  testWidgets('FisherGO web encyclopedia renders sample fish cards',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    await tester.pumpWidget(const FisherGoApp());
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(seconds: 3));

    expect(find.text('Fisher Lv. 1'), findsOneWidget);
    expect(find.textContaining('探索水域'), findsOneWidget);
    expect(find.textContaining('附近'), findsOneWidget);
    expect(find.text('圖鑑'), findsOneWidget);
    expect(find.text('背包'), findsOneWidget);
    expect(find.text('上魚獲'), findsOneWidget);
    expect(find.text('排行'), findsOneWidget);
  });
}
