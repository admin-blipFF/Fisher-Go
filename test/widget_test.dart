import 'package:flutter_test/flutter_test.dart';

import 'package:fishergo/main.dart';

void main() {
  testWidgets('FisherGO app shell renders bottom navigation', (tester) async {
    await tester.pumpWidget(const FisherGoApp());

    expect(find.text('香港魚類圖鑑'), findsOneWidget);
    expect(find.text('圖鑑'), findsOneWidget);
    expect(find.text('魚獲'), findsOneWidget);
    expect(find.text('排行'), findsOneWidget);
    expect(find.text('個人'), findsOneWidget);
  });
}
