import 'package:fishergo/core/config/supabase_project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts the canonical Supabase project host', () {
    final canonical = Uri.parse(
      'https://abcdefghijklmnopqrst.supabase.co',
    );
    expect(
      isTrustedSupabaseUrl(
        canonical,
        'abcdefghijklmnopqrst',
      ),
      isTrue,
    );
    expect(
      isTrustedSupabaseUrl(
        Uri.parse('https://abcdefghijklmnopqrst.supabase.co/'),
        'abcdefghijklmnopqrst',
      ),
      isTrue,
    );
  });

  test('rejects lookalike hosts and non-canonical URL components', () {
    const projectRef = 'abcdefghijklmnopqrst';
    expect(
      isTrustedSupabaseUrl(
        Uri.parse('https://$projectRef.attacker.example'),
        projectRef,
      ),
      isFalse,
    );
    expect(
      isTrustedSupabaseUrl(
        Uri.parse('http://$projectRef.supabase.co'),
        projectRef,
      ),
      isFalse,
    );
    expect(
      isTrustedSupabaseUrl(
        Uri.parse('https://$projectRef.supabase.co:444'),
        projectRef,
      ),
      isFalse,
    );
    expect(
      isTrustedSupabaseUrl(
        Uri.parse('https://$projectRef.supabase.co/proxy'),
        projectRef,
      ),
      isFalse,
    );
  });
}
