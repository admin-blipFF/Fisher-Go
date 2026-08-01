import 'package:fishergo/core/config/supabase_rpc_errors.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('recognizes a missing function error for the requested RPC', () {
    const error = 'PostgrestException(message: Could not find the function '
        'public.start_virtual_fishing_session(p_fish_id, p_lure_id, p_spot_id) '
        'in the schema cache, code: PGRST202)';

    expect(
      isMissingSupabaseRpc(error, 'start_virtual_fishing_session'),
      isTrue,
    );
  });

  test('does not treat an unrelated PGRST202 as a missing requested RPC', () {
    const error = 'PostgrestException(message: Could not find the function '
        'public.other_function() in the schema cache, code: PGRST202)';

    expect(
      isMissingSupabaseRpc(error, 'start_virtual_fishing_session'),
      isFalse,
    );
  });

  test('does not treat a same-name non-missing RPC error as a fallback case',
      () {
    const error = 'PostgrestException(message: invalid parameter for '
        'start_virtual_fishing_session, code: PGRST202)';

    expect(
      isMissingSupabaseRpc(error, 'start_virtual_fishing_session'),
      isFalse,
    );
  });
}
