import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File(
    'lib/features/profile/presentation/profile_screen.dart',
  ).readAsStringSync();

  test('daily task semantics distinguish progress and reward states', () {
    expect(source, contains('dailyTaskSemanticsLabel'));
    expect(source, contains('dailyTaskProgressSemanticsLabel'));
    expect(source, contains('dailyTaskClaimSemanticsLabel'));
    expect(source, contains('dailyTaskClaimedSemanticsLabel'));
    expect(source, contains("value: '\${task.current}/\${task.target}'"));
    expect(source, contains('onTap: () => _claimDailyTaskReward(task)'));
    expect(source, contains('ExcludeSemantics'));
  });
}
