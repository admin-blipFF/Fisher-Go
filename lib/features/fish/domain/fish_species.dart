class FishSpecies {
  const FishSpecies({
    required this.id,
    required this.commonNameZh,
    this.afcdId,
    this.commonNameEn,
    this.scientificName,
    this.family,
    this.descriptionZh,
    this.habitatZh,
    this.dangerLevel = 'unknown',
    this.imageUrl,
    this.silhouetteUrl,
  });

  final String id;
  final String? afcdId;
  final String commonNameZh;
  final String? commonNameEn;
  final String? scientificName;
  final String? family;
  final String? descriptionZh;
  final String? habitatZh;
  final String dangerLevel;
  final String? imageUrl;
  final String? silhouetteUrl;

  factory FishSpecies.fromMap(Map<String, dynamic> map) => FishSpecies(
        id: map['id'] as String,
        afcdId: map['afcd_id'] as String?,
        commonNameZh: map['common_name_zh'] as String,
        commonNameEn: map['common_name_en'] as String?,
        scientificName: map['scientific_name'] as String?,
        family: map['family'] as String?,
        descriptionZh: map['description_zh'] as String?,
        habitatZh: map['habitat_zh'] as String?,
        dangerLevel: (map['danger_level'] as String?) ?? 'unknown',
        imageUrl: map['image_url'] as String?,
        silhouetteUrl: map['silhouette_url'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'afcd_id': afcdId,
        'common_name_zh': commonNameZh,
        'common_name_en': commonNameEn,
        'scientific_name': scientificName,
        'family': family,
        'description_zh': descriptionZh,
        'habitat_zh': habitatZh,
        'danger_level': dangerLevel,
        'image_url': imageUrl,
        'silhouette_url': silhouetteUrl,
      };
}
