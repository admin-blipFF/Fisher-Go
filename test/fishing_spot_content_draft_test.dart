import 'package:flutter_test/flutter_test.dart';

import 'package:fishergo/core/admin/fishing_spot_content_draft.dart';

void main() {
  test('parses and normalizes habitat tags from comma/newline input', () {
    final tags = FishingSpotContentDraft.parseHabitatTags(
      ' Nearshore, pier\nTsing-Ma-Waters, nearshore ',
    );

    expect(tags, ['nearshore', 'pier', 'tsing-ma-waters']);
  });

  test('parses fish weights and rejects malformed or unsafe values', () {
    final weights = FishingSpotContentDraft.parseSpeciesWeights(
      'fish-103 = 4\nfish-109: 1.5',
    );

    expect(weights, {'fish-103': 4, 'fish-109': 1.5});
    expect(
      () => FishingSpotContentDraft.parseSpeciesWeights('fish-103=0'),
      throwsFormatException,
    );
    expect(
      () => FishingSpotContentDraft.parseSpeciesWeights('goldfish=2'),
      throwsFormatException,
    );
  });

  test('formats weights in stable fish-id order for the admin editor', () {
    expect(
      FishingSpotContentDraft.formatSpeciesWeights({
        'fish-109': 1.5,
        'fish-103': 4,
      }),
      'fish-103 = 4\nfish-109 = 1.5',
    );
  });
}
