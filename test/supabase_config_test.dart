import 'package:fishergo/core/config/supabase_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('does not treat missing compile-time public config as configured', () {
    expect(SupabaseConfig.url, isEmpty);
    expect(SupabaseConfig.anonKey, isEmpty);
    expect(SupabaseConfig.isConfigured, isFalse);
  });
}
