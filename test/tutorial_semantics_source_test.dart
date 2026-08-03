import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tutorial exposes progress and skip semantics', () {
    final source = File(
      'lib/features/tutorial/presentation/tutorial_overlay.dart',
    ).readAsStringSync();

    expect(source, contains('liveRegion: true'));
    expect(
      source,
      contains(r'教學第 ${_currentStep + 1} 頁，共 $_totalSteps 頁'),
    );
    expect(source, contains("label: '略過教學'"));
    expect(source, contains("hint: '跳過教學並開始遊戲'"));
    expect(source, contains('ExcludeSemantics'));
  });
}
