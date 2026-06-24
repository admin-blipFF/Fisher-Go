import 'package:flutter_test/flutter_test.dart';
import 'package:fishergo/core/permissions/android_permission_gate.dart';

void main() {
  test('serializes permission requests so only one runs at a time', () async {
    var running = 0;
    var maxRunning = 0;

    Future<int> request(int value) {
      return AndroidPermissionGate.run(() async {
        running++;
        maxRunning = running > maxRunning ? running : maxRunning;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        running--;
        return value;
      });
    }

    final results = await Future.wait([request(1), request(2), request(3)]);

    expect(results, [1, 2, 3]);
    expect(maxRunning, 1);
  });
}
