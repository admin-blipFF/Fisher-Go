import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release readiness audit is read-only and has an explicit strict mode',
      () {
    final source =
        File('tool/verify_release_readiness.dart').readAsStringSync();

    expect(source, contains('FisherGO release readiness (read-only)'));
    expect(source, contains("arguments.contains('--strict')"));
    expect(source, contains("'jarsigner'"));
    expect(source, isNot(contains('flutter build')));
    expect(source, isNot(contains('vercel deploy')));
    expect(source, isNot(contains('supabase db push')));
    expect(source, isNot(contains('supabase migration up')));
  });
}
