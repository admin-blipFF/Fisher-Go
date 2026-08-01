import 'package:flutter_test/flutter_test.dart';

import 'package:fishergo/features/leaderboard/data/public_leaderboard_service.dart';

void main() {
  test('parses a privacy-safe public leaderboard row', () {
    final entry = PublicLeaderboardEntry.fromMap({
      'species_id': 'fish-010',
      'species_name': '紅衫魚',
      'length_cm': 31.5,
      'verified_at': '2026-07-31T02:00:00Z',
      'score': 4,
    });

    expect(entry.speciesId, 'fish-010');
    expect(entry.speciesName, '紅衫魚');
    expect(entry.lengthCm, 31.5);
    expect(entry.score, 4);
    expect(entry.verifiedAt, isNotNull);
  });

  test('missing optional length and timestamp remain nullable', () {
    final entry = PublicLeaderboardEntry.fromMap({
      'species_name': '未知魚種',
      'score': 1,
    });

    expect(entry.speciesId, isNull);
    expect(entry.lengthCm, isNull);
    expect(entry.verifiedAt, isNull);
  });
}
