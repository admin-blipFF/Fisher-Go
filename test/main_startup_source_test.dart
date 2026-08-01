import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('does not create an anonymous session during global startup', () {
    final source = File('lib/main.dart').readAsStringSync();
    final runAppIndex = source.indexOf('runApp(const FisherGoBootstrap())');
    final backgroundSignInIndex =
        source.indexOf('unawaited(_signInAnonymouslyIfNeeded())');
    final networkSignInIndex = source.indexOf('await auth.signInAnonymously()');

    expect(runAppIndex, greaterThanOrEqualTo(0));
    expect(backgroundSignInIndex, -1);
    expect(networkSignInIndex, -1);
    expect(source, contains('class FisherGoBootstrap extends StatefulWidget'));
    expect(source, contains('FisherGO 正在準備海圖'));
    expect(source, contains('WidgetsBinding.instance.addPostFrameCallback'));
    expect(source, contains('FlutterError.onError'));
    expect(source, contains('FlutterError.onError ??='));
    expect(source, contains('PlatformDispatcher.instance.onError'));
    expect(source, contains('PlatformDispatcher.instance.onError ??='));
    expect(source, contains('TelemetryEventName.appError'));
  });
}
