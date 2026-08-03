import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('local Supabase Auth keeps the cloud guest path enabled', () {
    final config = File('supabase/config.toml').readAsStringSync();

    expect(
      config,
      matches(
        RegExp(r'^\s*enable_signup\s*=\s*true\s*$', multiLine: true),
      ),
    );
    expect(
      config,
      matches(
        RegExp(
          r'^\s*enable_anonymous_sign_ins\s*=\s*true\s*$',
          multiLine: true,
        ),
      ),
    );
    expect(
      config,
      matches(RegExp(r'^\s*anonymous_users\s*=\s*30\s*$', multiLine: true)),
    );
  });
}
