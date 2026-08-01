import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('catch photo smoke uses bounded REST operations and cleanup', () {
    final source = File(
      'tool/verify_supabase_catch_photo_storage.dart',
    ).readAsStringSync();

    expect(source, contains('FISHERGO_SMOKE_ANONYMOUS'));
    expect(source, contains("'/auth/v1/signup'"));
    expect(source, contains("'/auth/v1/token?grant_type=password'"));
    expect(source, contains("'/storage/v1/object/sign/\$_bucket'"));
    expect(source, contains('client.close()'));
    expect(source, contains('x-upsert'));
    expect(source, contains('access_token'));
    expect(source, contains('signedURL'));
    expect(source, contains('List<Object?>()'));
    expect(source, contains('bounded HTTP client'));
    expect(source, contains('response.statusCode != 200'));
    expect(source, contains('_operationTimeout'));
    expect(source, contains('_cleanupTimeout'));
    expect(source, contains('cleanup failed'));
  });
}
