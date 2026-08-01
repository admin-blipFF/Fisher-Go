import 'package:flutter_test/flutter_test.dart';

import 'package:fishergo/core/config/auth_redirect_config.dart';

void main() {
  test('mobile OAuth uses a native callback scheme', () {
    expect(AuthRedirectConfig.mobile, 'fishergo://auth/callback');
  });

  test('web OAuth keeps the production HTTPS callback', () {
    expect(AuthRedirectConfig.web, 'https://fisher-go.app');
  });
}
