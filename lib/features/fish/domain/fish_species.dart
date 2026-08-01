class FishSpecies {
  const FishSpecies({
    required this.id,
    required this.commonNameZh,
    this.localNameZh,
    this.afcdId,
    this.commonNameEn,
    this.scientificName,
    this.family,
    this.descriptionZh,
    this.habitatZh,
    this.dangerLevel = 'unknown',
    this.fishType,
    this.bodyShape,
    this.rarityRank = 1,
    this.imageUrl,
    this.silhouetteUrl,
  });

  final String id;
  final String? afcdId;
  final String commonNameZh;
  final String? localNameZh;
  final String? commonNameEn;
  final String? scientificName;

  String get displayLocalName =>
      (localNameZh != null && localNameZh!.trim().isNotEmpty)
          ? localNameZh!.trim()
          : commonNameZh;

  String get displayNameLocalSlashCommon {
    final common = commonNameZh.trim();
    if (displayLocalName == common) return common;
    return '$displayLocalName｜$common';
  }

  final String? family;
  final String? descriptionZh;
  final String? habitatZh;
  final String dangerLevel;
  final String? fishType;
  final String? bodyShape;
  final int rarityRank;
  final String? imageUrl;
  final String? silhouetteUrl;

  factory FishSpecies.fromMap(Map<String, dynamic> map) => FishSpecies(
        id: map['id'] as String,
        afcdId: map['afcd_id'] as String?,
        commonNameZh: map['common_name_zh'] as String,
        localNameZh:
            (map['local_name_zh'] as String?) ?? (map['local_name'] as String?),
        commonNameEn: map['common_name_en'] as String?,
        scientificName: map['scientific_name'] as String?,
        family: map['family'] as String?,
        descriptionZh: map['description_zh'] as String?,
        habitatZh: map['habitat_zh'] as String?,
        dangerLevel: (map['danger_level'] as String?) ?? 'unknown',
        fishType: map['fish_type'] as String?,
        bodyShape: map['body_shape'] as String?,
        rarityRank: (map['rarity_rank'] as num?)?.toInt() ?? 1,
        imageUrl: normalizeFishAssetUrl(map['image_url'] as String?),
        silhouetteUrl: map['silhouette_url'] as String?,
      );

  FishSpecies copyWith({
    String? id,
    String? afcdId,
    String? commonNameZh,
    String? localNameZh,
    String? commonNameEn,
    String? scientificName,
    String? family,
    String? descriptionZh,
    String? habitatZh,
    String? dangerLevel,
    String? fishType,
    String? bodyShape,
    int? rarityRank,
    String? imageUrl,
    String? silhouetteUrl,
  }) =>
      FishSpecies(
        id: id ?? this.id,
        afcdId: afcdId ?? this.afcdId,
        commonNameZh: commonNameZh ?? this.commonNameZh,
        localNameZh: localNameZh ?? this.localNameZh,
        commonNameEn: commonNameEn ?? this.commonNameEn,
        scientificName: scientificName ?? this.scientificName,
        family: family ?? this.family,
        descriptionZh: descriptionZh ?? this.descriptionZh,
        habitatZh: habitatZh ?? this.habitatZh,
        dangerLevel: dangerLevel ?? this.dangerLevel,
        fishType: fishType ?? this.fishType,
        bodyShape: bodyShape ?? this.bodyShape,
        rarityRank: rarityRank ?? this.rarityRank,
        imageUrl: imageUrl ?? this.imageUrl,
        silhouetteUrl: silhouetteUrl ?? this.silhouetteUrl,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'afcd_id': afcdId,
        'common_name_zh': commonNameZh,
        'local_name_zh': localNameZh,
        'common_name_en': commonNameEn,
        'scientific_name': scientificName,
        'family': family,
        'description_zh': descriptionZh,
        'habitat_zh': habitatZh,
        'danger_level': dangerLevel,
        'fish_type': fishType,
        'body_shape': bodyShape,
        'rarity_rank': rarityRank,
        'image_url': imageUrl,
        'silhouette_url': silhouetteUrl,
      };
}

String? normalizeFishAssetUrl(String? value) {
  if (value == null) return null;
  final normalized = value
      .replaceFirst(
        'assets/fish/icons/generated/',
        'assets/fish/mobile_webp/',
      )
      .replaceFirst(
        'assets/fish/mobile/',
        'assets/fish/mobile_webp/',
      );
  if (normalized.startsWith('assets/fish/mobile_webp/') &&
      normalized.endsWith('.png')) {
    return '${normalized.substring(0, normalized.length - 4)}.webp';
  }
  return normalized;
}

/// Returns the compact transparent artwork used by game surfaces.
///
/// Catalog sources historically point at generated `*-badge` assets. Those
/// badges are useful for data compatibility but include a square background;
/// gameplay surfaces need the matching transparent WebP instead.
String? fishGameArtworkAssetPath(String? value) {
  final normalized = normalizeFishAssetUrl(value);
  if (normalized == null ||
      !normalized.startsWith('assets/fish/mobile_webp/')) {
    return normalized;
  }

  final localBadge = RegExp(r'/([0-9]{3})(?:_|-)').firstMatch(normalized);
  if (normalized.endsWith('-local-badge.webp') && localBadge != null) {
    return 'assets/fish/mobile_webp/${localBadge.group(1)}.webp';
  }

  return normalized.replaceFirst(
    RegExp(r'[-_]badge\.webp$'),
    '.webp',
  );
}
