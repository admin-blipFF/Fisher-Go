import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:fishergo/core/tutorial/tutorial_service.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir =
        await Directory.systemTemp.createTemp('fishergo_tutorial_hive_test_');
    Hive.init(tempDir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
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

    test('reset followed by isCompleted returns false', () async {
      // Verify the reset actually persists
      await TutorialService.reset();
      final result = await TutorialService.isCompleted();
      expect(result, false);
    });
  });
}