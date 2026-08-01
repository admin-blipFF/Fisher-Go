import 'public_app_config.dart';

class SupabaseConfig {
  static String get url {
    return _normalizeValue(PublicAppConfig.supabaseUrl);
  }

  static String get anonKey {
    return _normalizeValue(PublicAppConfig.supabaseAnonKey);
  }

  static String _normalizeValue(String value) =>
      value.replaceFirst('\uFEFF', '').trim();

  static bool get isConfigured {
    final configuredUrl = url;
    final configuredAnonKey = anonKey;
    return configuredUrl.startsWith('https://') &&
        configuredUrl.contains('.supabase.co') &&
        !configuredUrl.contains('example.supabase.co') &&
        configuredAnonKey.isNotEmpty &&
        configuredAnonKey != 'dev-placeholder' &&
        configuredAnonKey != 'your-anon-key';
  }
}
