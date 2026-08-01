import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'startup integration waits for states instead of assuming cold-start timing',
      () {
    final source = File(
      'integration_test/startup_auth_flow_test.dart',
    ).readAsStringSync();

    expect(source, contains('Future<void> _pumpUntil('));
    expect(source, contains('DateTime.now().add(timeout)'));
    expect(source, contains('timeout: const Duration(seconds: 60)'));
    expect(source, contains("find.text('全部')"));
    expect(
      source,
      isNot(
          contains('await tester.pumpAndSettle(const Duration(seconds: 2));')),
    );
  });
}
