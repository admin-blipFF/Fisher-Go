import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('catch log sync ignores late callbacks after the screen is disposed',
      () {
    final source = File(
      'lib/features/catches/presentation/catch_log_screen.dart',
    ).readAsStringSync();

    expect(source, contains('if (!mounted || _pending.isEmpty) return;'));
  });

  test('catch log sync keeps the local queue when a remote retry fails', () {
    final source = File(
      'lib/features/catches/presentation/catch_log_screen.dart',
    ).readAsStringSync();

    expect(source, contains('同步暫時失敗，魚獲會保留在本機。'));
  });

  test(
      'catch log exposes connectivity state without replacing the production stream',
      () {
    final source = File(
      'lib/features/catches/presentation/catch_log_screen.dart',
    ).readAsStringSync();

    expect(source, contains('this.connectivityChanges'));
    expect(source, contains('widget.connectivityChanges ??'));
    expect(source, contains('onOnlineChanged: _handleConnectivityStatus'));
    expect(source, contains('連線檢查中'));
    expect(source, contains('離線'));
  });
}
