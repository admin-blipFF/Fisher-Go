import 'package:fishergo/core/config/supabase_config.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('treats BOM-prefixed Supabase URL as configured', () {
    dotenv.loadFromString(
      envString: [
        'SUPABASE_URL=\uFEFFhttps://project.supabase.co',
        'SUPABASE_ANON_KEY=sb_publishable_test_key',
      ].join('\n'),
    );

    expect(SupabaseConfig.url, 'https://project.supabase.co');
    expect(SupabaseConfig.isConfigured, isTrue);
  });
}
