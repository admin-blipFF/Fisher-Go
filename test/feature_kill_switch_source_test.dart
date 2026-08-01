import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release kill switches guard every high-risk content entry point', () {
    final config =
        File('lib/core/config/public_app_config.dart').readAsStringSync();
    final eventRules = File(
      'lib/features/game_home/domain/fishing_event_rules.dart',
    ).readAsStringSync();
    final recognition = File(
      'lib/features/catches/data/fish_recognition_service.dart',
    ).readAsStringSync();
    final spots = File(
      'lib/features/fishing_spots/data/fishing_spot_repository.dart',
    ).readAsStringSync();

    expect(config, contains("FISHERGO_EVENTS_ENABLED"));
    expect(config, contains("FISHERGO_RECOGNITION_ENABLED"));
    expect(config, contains("FISHERGO_SPOTS_ENABLED"));
    expect(eventRules, contains('PublicAppConfig.eventsEnabled'));
    expect(
      recognition,
      contains('PublicAppConfig.fishRecognitionEnabled'),
    );
    expect(spots, contains('PublicAppConfig.fishingSpotsEnabled'));
  });
}
