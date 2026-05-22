import 'package:flutter_test/flutter_test.dart';

import 'package:fishergo/main.dart';

void main() {
  testWidgets('FisherGO web encyclopedia renders sample fish cards',
      (tester) async {
    await tester.pumpWidget(const FisherGoApp());
    await tester.pumpAndSettle();

    expect(find.text('FisherGO Web 圖鑑'), findsOneWidget);
    expect(find.text('黃腳鱲'), findsOneWidget);
    expect(find.text('黑鯛'), findsOneWidget);
    expect(find.text('未解鎖魚種'), findsWidgets);
    expect(find.text('圖鑑'), findsOneWidget);
    expect(find.text('魚獲'), findsOneWidget);
    expect(find.text('排行'), findsOneWidget);
    expect(find.text('個人'), findsOneWidget);
  });
}
