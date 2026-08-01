import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File(
    'supabase${Platform.pathSeparator}functions${Platform.pathSeparator}'
    'recognize-fish${Platform.pathSeparator}index.ts',
  ).readAsStringSync();

  test('recognition prompt is server-owned and result ids are allowlisted', () {
    expect(source, contains('SERVER_SYSTEM_PROMPT'));
    expect(source, contains('GAME_SPECIES_ID_PATTERN'));
    expect(source, contains('allowedSpeciesIds.has(speciesId)'));
    expect(source, isNot(contains('body.system_prompt')));
  });

  test('client sends catalog hints instead of executable prompt text', () {
    final service = File(
      'lib${Platform.pathSeparator}features${Platform.pathSeparator}'
      'catches${Platform.pathSeparator}data${Platform.pathSeparator}'
      'fish_recognition_service.dart',
    ).readAsStringSync();

    expect(service, contains("'species_catalog':"));
    expect(service, isNot(contains("'system_prompt':")));
  });
}
