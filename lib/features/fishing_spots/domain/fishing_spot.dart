import 'dart:math' as math;

enum FishingSpotKind {
  shore,
  pier,
  rock,
  island,
  reservoir,
  pond,
  boat,
}

enum FishingSpotVerificationStatus {
  draft,
  communityReported,
  verified,
  suspended,
}

class FishingSpot {
  const FishingSpot({
    required this.id,
    required this.nameZh,
    this.nameEn,
    required this.latitude,
    required this.longitude,
    required this.coordinatePrecisionMeters,
    required this.kind,
    required this.status,
    required this.publicAccess,
    required this.safetyNotes,
    required this.source,
    required this.sourceReference,
    required this.reviewer,
    required this.reviewedAt,
    required this.active,
    this.habitatTags = const [],
    this.speciesWeights = const {},
    this.environment = 'coastal',
  });

  final String id;
  final String nameZh;
  final String? nameEn;
  final double latitude;
  final double longitude;
  final double coordinatePrecisionMeters;
  final FishingSpotKind kind;
  final FishingSpotVerificationStatus status;
  final bool publicAccess;
  final String safetyNotes;
  final String source;
  final String sourceReference;
  final String reviewer;
  final DateTime reviewedAt;
  final bool active;
  final List<String> habitatTags;
  final Map<String, double> speciesWeights;
  final String environment;

  String get displayName => nameZh.trim().isNotEmpty
      ? nameZh.trim()
      : (nameEn?.trim().isNotEmpty == true ? nameEn!.trim() : id);

  bool get isActiveVerified =>
      active && status == FishingSpotVerificationStatus.verified;

  bool isWithinRadius({
    required double centerLatitude,
    required double centerLongitude,
    required double radiusMeters,
  }) {
    return distanceMeters(
          latitude,
          longitude,
          centerLatitude,
          centerLongitude,
        ) <=
        radiusMeters;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name_zh': nameZh,
        'name_en': nameEn,
        'latitude': latitude,
        'longitude': longitude,
        'coordinate_precision_m': coordinatePrecisionMeters,
        'kind': kind.name,
        'verification_status': status.name,
        'public_access': publicAccess,
        'safety_notes': safetyNotes,
        'source': source,
        'source_reference': sourceReference,
        'reviewer': reviewer,
        'reviewed_at': reviewedAt.toUtc().toIso8601String(),
        'active': active,
        'habitat_tags': habitatTags,
        'species_weights': speciesWeights,
        'environment': environment,
      };

  factory FishingSpot.fromMap(Map<String, dynamic> map) => FishingSpot(
        id: map['id'] as String,
        nameZh: (map['name_zh'] as String?) ?? '',
        nameEn: map['name_en'] as String?,
        latitude: (map['latitude'] as num).toDouble(),
        longitude: (map['longitude'] as num).toDouble(),
        coordinatePrecisionMeters:
            (map['coordinate_precision_m'] as num?)?.toDouble() ?? 50,
        kind: _parseKind(map['kind'] as String?),
        status: _parseStatus(map['verification_status'] as String?),
        publicAccess: map['public_access'] as bool? ?? false,
        safetyNotes: (map['safety_notes'] as String?) ?? '',
        source: (map['source'] as String?) ?? '',
        sourceReference: (map['source_reference'] as String?) ?? '',
        reviewer: (map['reviewer'] as String?) ?? '',
        reviewedAt: DateTime.tryParse(map['reviewed_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        active: map['active'] as bool? ?? false,
        habitatTags:
            (map['habitat_tags'] as List?)?.whereType<String>().toList() ??
                const [],
        speciesWeights: _parseWeights(map['species_weights']),
        environment: (map['environment'] as String?) ?? 'coastal',
      );

  static FishingSpotKind _parseKind(String? value) =>
      FishingSpotKind.values.firstWhere((kind) => kind.name == value,
          orElse: () => FishingSpotKind.shore);

  static FishingSpotVerificationStatus _parseStatus(String? value) =>
      FishingSpotVerificationStatus.values.firstWhere(
        (status) => status.name == value,
        orElse: () => FishingSpotVerificationStatus.draft,
      );

  static Map<String, double> _parseWeights(Object? value) {
    if (value is! Map) return const {};
    return value.map((key, item) => MapEntry(
          key.toString(),
          item is num ? item.toDouble() : 0,
        ));
  }
}

double distanceMeters(
  double latitudeA,
  double longitudeA,
  double latitudeB,
  double longitudeB,
) {
  const earthRadiusMeters = 6371008.8;
  final latA = _radians(latitudeA);
  final latB = _radians(latitudeB);
  final deltaLat = latB - latA;
  final deltaLon = _radians(longitudeB - longitudeA);
  final haversine = math.pow(math.sin(deltaLat / 2), 2) +
      math.cos(latA) * math.cos(latB) * math.pow(math.sin(deltaLon / 2), 2);
  return earthRadiusMeters * 2 * math.asin(math.sqrt(haversine.clamp(0, 1)));
}

double _radians(double degrees) => degrees * 3.141592653589793 / 180;
