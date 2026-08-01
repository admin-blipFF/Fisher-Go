import 'package:flutter/foundation.dart';

/// Redirect targets shared by web OAuth and native deep-link callbacks.
class AuthRedirectConfig {
  const AuthRedirectConfig._();

  static const web = 'https://fisher-go.app';
  static const mobile = 'fishergo://auth/callback';

  static String get oauthRedirect => kIsWeb ? web : mobile;
}
