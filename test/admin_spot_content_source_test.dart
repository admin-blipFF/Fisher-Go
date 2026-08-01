import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('admin operations expose a bounded fishing-spot content update', () {
    final source =
        File('lib/core/admin/admin_ops_service.dart').readAsStringSync();

    expect(source, contains('updateFishingSpotContent'));
    expect(source, contains("'habitat_tags'"));
    expect(source, contains("'species_weights'"));
    expect(source, contains('FishingSpotContentDraft'));
    expect(source, contains("'reviewed_at'"));
  });

  test('admin screen exposes habitat and spawn-weight editing', () {
    final source = File('lib/features/admin/presentation/admin_screen.dart')
        .readAsStringSync();

    expect(source, contains('編輯棲地及魚種權重'));
    expect(source, contains('habitat_tags'));
    expect(source, contains('species_weights'));
    expect(source, contains('updateFishingSpotContent'));
  });

  test('fishing-spot content migration validates machine-readable values', () {
    final migration = File(
      'supabase/migrations/0024_fishing_spot_content_constraints.sql',
    ).readAsStringSync();

    expect(migration, contains('fishing_spots_habitat_tags_shape_check'));
    expect(migration, contains('fishing_spots_species_weights_shape_check'));
    expect(migration, contains("public.is_admin()"));
    expect(migration, contains('create policy "admins update fishing spots"'));
  });
}
