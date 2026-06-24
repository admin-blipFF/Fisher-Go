import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  static const String _urlFromDefine = String.fromEnvironment('SUPABASE_URL');
  static const String _anonKeyFromDefine = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  static String get url {
    final urlFromDefine = _normalizeValue(_urlFromDefine);
    return urlFromDefine.isNotEmpty ? urlFromDefine : _envValue('SUPABASE_URL');
  }

  static String get anonKey {
    final anonKeyFromDefine = _normalizeValue(_anonKeyFromDefine);
    return anonKeyFromDefine.isNotEmpty
        ? anonKeyFromDefine
        : _envValue('SUPABASE_ANON_KEY');
  }

  static String _envValue(String key) {
    try {
      return _normalizeValue(dotenv.env[key] ?? '');
    } catch (_) {
      return '';
    }
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
