import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('spot habitat migration is additive and auditable', () {
    final source = File(
      'supabase/migrations/0017_fishing_spot_habitat_weights.sql',
    ).readAsStringSync();

    expect(source, contains('update public.fishing_spots'));
    expect(source, contains('species_weights'));
    expect(source, contains('habitat_tags'));
    expect(source, contains("where id in ('P017', 'P018')"));
    expect(source, contains("where id in ('P045', 'P046', 'P047', 'P050')"));
    expect(source, contains("where id in ('P051', 'P052', 'P053', 'P054')"));
    expect(source, contains("where id in ('P035', 'P036', 'P043')"));
    expect(source, contains("'fish-103'"));
    expect(source, contains("'fish-063'"));
    expect(source, contains("'fish-073'"));
    expect(source, contains("'fish-140'"));
    expect(source, isNot(contains('drop table')));
    expect(source, isNot(contains('truncate')));
  });
}
