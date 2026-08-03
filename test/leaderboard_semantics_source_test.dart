import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('leaderboard screen wires dynamic and row semantics', () {
    final source = File(
      'lib/features/leaderboard/presentation/leaderboard_screen.dart',
    ).readAsStringSync();

    expect(source, contains("import 'leaderboard_semantics.dart';"));
    expect(source, contains('leaderboardLoadingSemanticsLabel()'));
    expect(source, contains('leaderboardErrorSemanticsLabel()'));
    expect(source, contains('leaderboardEmptySemanticsLabel()'));
    expect(source, contains('leaderboardSectionSemanticsLabel(rows.length)'));
    expect(source, contains('leaderboardRowSemanticsLabel('));
    expect(source, contains('liveRegion: true'));
    expect(source, contains('excludeSemantics: true'));
  });
}
