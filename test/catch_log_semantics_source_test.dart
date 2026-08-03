import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:fishergo/features/catches/presentation/catch_log_semantics.dart';

void main() {
  final source = File(
    'lib/features/catches/presentation/catch_log_screen.dart',
  ).readAsStringSync();

  test('catch-log map spot labels distinguish a single spot from a cluster',
      () {
    expect(catchLogSpotSemanticsLabel(1), '釣點');
    expect(catchLogSpotSemanticsLabel(3), '3 個釣點');
    expect(source, contains('catchLogSpotSemanticsLabel'));
  });

  test('catch-log radar toggle describes its next action', () {
    expect(catchLogRadarSemanticsLabel(true), '自動打點已啟用，切換為手動');
    expect(catchLogRadarSemanticsLabel(false), '自動打點已停用，切換為自動');
    expect(source, contains('catchLogRadarSemanticsLabel'));
  });

  test('custom catch-log controls expose explicit semantics', () {
    expect(source, contains("label: '選擇魚獲相片'"));
    expect(source, contains('class _GameSideHudButton'));
    expect(source, contains('class _GameHudButton'));
    expect(source, contains('excludeSemantics: true'));
  });

  test('custom catch-log semantics nodes keep their activation actions', () {
    expect(source, contains('onTap: onTap'));
    expect(source, contains('onTap: onToggleAuto'));
    expect(source, contains('onTap: _resolved ? _finish : _pullRod'));
    expect(source, contains('void onTap() {'));
  });
}
