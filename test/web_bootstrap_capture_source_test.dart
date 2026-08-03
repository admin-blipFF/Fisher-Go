import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'Web bootstrap capture counts bytes received while requests are in flight',
      () {
    final source = File('tool/web_bootstrap_capture.js').readAsStringSync();

    expect(source, contains("Network.enable"));
    expect(source, contains("Network.dataReceived"));
    expect(source, contains('encodedDataLength'));
    expect(source, contains('initial_2s_in_flight_bytes'));
    expect(source, contains('initial_2s_completed_bytes'));
    expect(source, contains('initial_2s_fish_media_bytes'));
    expect(source, contains('capture_url'));
    expect(source, contains('targetOrigin'));
    expect(source, contains('fishMediaPath'));
    expect(source, contains('/assets/fish/mobile/'));
    expect(source, contains('const navigation = page.goto'));
    expect(source, contains('await navigation'));
  });
}
