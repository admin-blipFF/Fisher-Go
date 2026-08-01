import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('event configuration is served through a bounded RPC', () {
    final migration = File(
      'supabase/migrations/0022_server_event_configuration.sql',
    ).readAsStringSync().toLowerCase();
    final service =
        File('lib/core/admin/admin_ops_service.dart').readAsStringSync();

    expect(migration, contains('get_active_fishing_event_config'));
    expect(migration, contains('ae.ends_at'));
    expect(migration, contains('frb.ends_at'));
    expect(migration, contains('revoke all on function'));
    expect(service, contains("rpc('get_active_fishing_event_config')"));
  });
}
