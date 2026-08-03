import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('secondary-screen smoke traverses the Profile shop subflows', () {
    final source = File(
      'integration_test/secondary_screen_accessibility_flow_test.dart',
    ).readAsStringSync();

    expect(source, contains("scrollUntilVisible"));
    expect(source, contains("find.bySemanticsLabel('裝備商店')"));
    expect(source, contains("find.bySemanticsLabel('釣魚道具商城')"));
    expect(source, contains('可購買並裝備到外圍裝備槽'));
    expect(source, contains('魚餌、誘餌、探測器與掃描券'));
    expect(source, contains('await tester.pageBack()'));
  });
}
