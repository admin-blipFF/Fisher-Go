import 'package:flutter_test/flutter_test.dart';

import 'package:fishergo/features/fishing_spots/domain/fishing_spot.dart';

FishingSpot _spot({
  String source = 'Government pier register',
  String sourceReference = 'https://example.test/pier',
  String reviewer = 'fishergo-team',
  DateTime? reviewedAt,
  double latitude = 22.3000,
  double longitude = 114.1700,
  double precision = 20,
}) {
  return FishingSpot(
    id: 'audit-test',
    nameZh: '審核測試釣點',
    latitude: latitude,
    longitude: longitude,
    coordinatePrecisionMeters: precision,
    kind: FishingSpotKind.pier,
    status: FishingSpotVerificationStatus.verified,
    publicAccess: true,
    safetyNotes: 'test',
    source: source,
    sourceReference: sourceReference,
    reviewer: reviewer,
    reviewedAt: reviewedAt ?? DateTime.utc(2026, 7, 18),
    active: true,
  );
}

void main() {
  test('public eligibility requires an auditable review trail', () {
    expect(_spot().isPubliclyEligible, isTrue);
    expect(_spot(source: '').isPubliclyEligible, isFalse);
    expect(_spot(sourceReference: '').isPubliclyEligible, isFalse);
    expect(_spot(reviewer: '').isPubliclyEligible, isFalse);
    expect(
      _spot(reviewedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true))
          .isPubliclyEligible,
      isFalse,
    );
  });

  test('public eligibility rejects malformed coordinates and precision', () {
    expect(_spot(latitude: 91).isPubliclyEligible, isFalse);
    expect(_spot(longitude: -181).isPubliclyEligible, isFalse);
    expect(_spot(precision: 0).isPubliclyEligible, isFalse);
  });
}
