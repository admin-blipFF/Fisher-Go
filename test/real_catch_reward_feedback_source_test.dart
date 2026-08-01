import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('real catch feedback only promises coins after wallet confirmation', () {
    final source = File(
      'lib/features/catches/presentation/catch_log_screen.dart',
    ).readAsStringSync();

    expect(
      source,
      contains('final rewardBalance = await ProfileWalletService.addCoins('),
    );
    expect(source, contains('if (rewardBalance >= 0)'));
    expect(source, contains('獎勵待伺服器確認'));
    expect(source, contains('（+20 金幣）'));
  });
}
