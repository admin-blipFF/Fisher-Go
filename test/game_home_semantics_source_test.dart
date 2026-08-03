import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File(
    'lib/features/game_home/presentation/game_home_screen.dart',
  ).readAsStringSync();

  test('map location control exposes an explicit state-aware label', () {
    expect(source, contains('enabled: !isLocating'));
    expect(source, contains('final semanticLabel = isLocating'));
    expect(source, contains('label: semanticLabel'));
    expect(source, contains("'重新定位，取得目前位置'"));
  });

  test('radar and announcement gestures expose button semantics', () {
    expect(
      source,
      contains("'雷達模式，已啟用，切換為手動'"),
    );
    expect(
      source,
      contains("'雷達模式，已停用，切換為自動'"),
    );
    expect(source, contains("'公告通知，有新公告'"));
    expect(source, contains("? '公告通知，有新公告' : '公告通知'"));
  });

  test('fishing overlay close action has a discoverable tooltip', () {
    expect(source, contains("tooltip: '關閉釣魚小遊戲'"));
  });

  test('side HUD buttons promote their activation callback to semantics', () {
    expect(
      source,
      contains('label: label,\n      onTap: onTap,'),
    );
    expect(source, contains('excludeFromSemantics: true'));
  });
}
