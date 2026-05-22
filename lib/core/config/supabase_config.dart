import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  static String get url => _envValue('SUPABASE_URL');
  static String get anonKey => _envValue('SUPABASE_ANON_KEY');

  static String _envValue(String key) {
    try {
      return dotenv.env[key] ?? '';
    } catch (_) {
      return '';
    }
  }

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
