import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'package:fishergo/core/config/public_app_config.dart';
import 'package:fishergo/features/catches/data/fish_recognition_service.dart';
import 'package:fishergo/features/fishing_spots/data/fishing_spot_repository.dart';
import 'package:fishergo/features/game_home/domain/fishing_event_rules.dart';

void main() {
  test('compiled event flag controls labels and multipliers', () {
    final labels = FishingEventRules.activeEventLabels(
      spotName: '青馬大橋橋底',
      now: DateTime(2026, 7, 31, 22),
    );
    final multiplier = FishingEventRules.eventMultiplier(
      spotName: '青馬大橋橋底',
      fishName: '石斑魚',
      fishId: 'fish-073',
      now: DateTime(2026, 7, 31, 22),
    );

    if (PublicAppConfig.eventsEnabled) {
      expect(labels, isNotEmpty);
      expect(multiplier, greaterThan(1));
    } else {
      expect(labels, isEmpty);
      expect(multiplier, 1.0);
    }
  });

  test('compiled spot flag controls the public registry', () async {
    final spots = await FishingSpotRepository(
      remoteRegistryEnabled: false,
    ).getActiveVerifiedSpots();

    if (PublicAppConfig.fishingSpotsEnabled) {
      expect(spots, isNotEmpty);
    } else {
      expect(spots, isEmpty);
    }
  });

  test('compiled recognition flag controls the request boundary', () async {
    final result = await FishRecognitionService().recognize(
      XFile.fromData(Uint8List.fromList(const [1, 2, 3])),
    );

    if (PublicAppConfig.fishRecognitionEnabled) {
      expect(result.errorMessage, contains('尚未設定'));
    } else {
      expect(result.errorMessage, contains('暫時關閉'));
    }
  });
}
