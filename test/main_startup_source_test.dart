import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('renders the app before anonymous network sign-in', () {
    final source = File('lib/main.dart').readAsStringSync();
    final runAppIndex = source.indexOf('runApp(const FisherGoBootstrap())');
    final backgroundSignInIndex =
        source.indexOf('unawaited(_signInAnonymouslyIfNeeded())');
    final networkSignInIndex = source.indexOf('await auth.signInAnonymously()');

    expect(runAppIndex, greaterThanOrEqualTo(0));
    expect(backgroundSignInIndex, greaterThan(runAppIndex));
    expect(networkSignInIndex, greaterThan(runAppIndex));
    expect(source, contains('class FisherGoBootstrap extends StatefulWidget'));
    expect(source, contains('FisherGO 正在準備海圖'));
    expect(source, contains('WidgetsBinding.instance.addPostFrameCallback'));
  });
}
