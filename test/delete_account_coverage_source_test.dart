import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('delete-account covers every migration table that owns user data', () {
    final functionSource = File(
      'supabase/functions/delete-account/index.ts',
    ).readAsStringSync();
    final tablePattern = RegExp(
      r'create\s+table(?:\s+if\s+not\s+exists)?\s+public\.([a-z0-9_]+)\s*\((.*?)^\s*\);',
      caseSensitive: false,
      multiLine: true,
      dotAll: true,
    );
    final migrationTables = <String>{};
    final migrationFiles = Directory('supabase/migrations')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.sql'));

    for (final file in migrationFiles) {
      final sql = file.readAsStringSync();
      for (final match in tablePattern.allMatches(sql)) {
        final table = match.group(1)!;
        final body = match.group(2)!;
        if (table == 'profiles' ||
            RegExp(r'\buser_id\b', caseSensitive: false).hasMatch(body)) {
          migrationTables.add(table);
        }
      }
    }

    final deletionTables = RegExp(r'table:\s*"([a-z0-9_]+)"')
        .allMatches(functionSource)
        .map((match) => match.group(1)!)
        .toSet();
    final missing = migrationTables.difference(deletionTables).toList()..sort();

    expect(migrationTables, isNotEmpty);
    expect(missing, isEmpty,
        reason: 'Add new user-owned tables to delete-account: $missing');
    expect(functionSource, contains('analytics_events'));
    expect(functionSource, contains('actor_key'));
  });
}
