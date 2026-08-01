import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:fishergo/core/tutorial/tutorial_service.dart';
import 'package:fishergo/features/tutorial/presentation/tutorial_overlay.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir =
        await Directory.systemTemp.createTemp('fishergo_tutorial_hive_test_');
    Hive.init(tempDir.path);
  });

  tearDownAll(() async {
    if (tempDir.existsSync()) {
      for (var attempt = 0; attempt < 3; attempt++) {
        try {
          tempDir.deleteSync(recursive: true);
          break;
        } on FileSystemException {
          // Hive can keep a file handle briefly after widget tests on Windows.
          if (attempt == 2) break;
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
      }
    }
  });

  setUp(() async {
    // Reset tutorial state before each test
    await TutorialService.reset();
  });

  group('TutorialService', () {
    test('isCompleted returns false by default', () async {
      // Ensure fresh state
      await TutorialService.reset();
      final result = await TutorialService.isCompleted();
      expect(result, false);
    });

    test('markCompleted sets tutorial to completed', () async {
      await TutorialService.markCompleted();
      final result = await TutorialService.isCompleted();
      expect(result, true);
    });

    test('skip tutorial uses the same completed state as finishing tutorial',
        () async {
      await TutorialService.markCompleted();

      final result = await TutorialService.isCompleted();

      expect(result, true);
    });

    test('reset clears tutorial completion', () async {
      await TutorialService.markCompleted();
      await TutorialService.reset();
      final result = await TutorialService.isCompleted();
      expect(result, false);
    });

    test('multiple markCompleted calls are idempotent', () async {
      await TutorialService.markCompleted();
      await TutorialService.markCompleted();
      final result = await TutorialService.isCompleted();
      expect(result, true);
    });

    test('completion is isolated by player identity', () async {
      await TutorialService.markCompleted(identityKey: 'player-a');

      expect(await TutorialService.isCompleted(identityKey: 'player-a'), true);
      expect(await TutorialService.isCompleted(identityKey: 'player-b'), false);
    });

    test('reset followed by isCompleted returns false', () async {
      // Verify the reset actually persists
      await TutorialService.reset();
      final result = await TutorialService.isCompleted();
      expect(result, false);
    });

    testWidgets('skip tutorial completes once and persists completion',
        (tester) async {
      var completionCount = 0;
      final completion = Completer<void>();

      await tester.pumpWidget(
        MaterialApp(
          home: TutorialOverlay(
            onStartFishing: () {},
            onComplete: () {
              completionCount++;
              if (!completion.isCompleted) {
                completion.complete();
              }
            },
          ),
        ),
      );

      final skipButton = find.widgetWithText(TextButton, '略過');

      await tester.tap(skipButton);
      await tester.pump();

      expect(tester.widget<TextButton>(skipButton).onPressed, isNull);

      await tester.tap(skipButton, warnIfMissed: false);
      for (var i = 0; i < 50 && !completion.isCompleted; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }

      expect(completionCount, 1);
      expect(await TutorialService.isCompleted(), true);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
