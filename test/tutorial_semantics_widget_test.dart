import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fishergo/features/tutorial/presentation/tutorial_overlay.dart';

void main() {
  testWidgets('tutorial exposes progress and skip nodes', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: TutorialOverlay(
            onStartFishing: () {},
            onComplete: () {},
          ),
        ),
      );

      expect(
        find.bySemanticsLabel('教學第 1 頁，共 4 頁'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('略過教學'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });
}
