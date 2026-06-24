enum FishDiscoveryStatus {
  unknown,
  encountered,
  gameCaught,
  verifiedRealCatch,
}

extension FishDiscoveryStatusX on FishDiscoveryStatus {
  String get storageValue => name;

  String get labelZh {
    switch (this) {
      case FishDiscoveryStatus.unknown:
        return '未發現';
      case FishDiscoveryStatus.encountered:
        return '已遇見';
      case FishDiscoveryStatus.gameCaught:
        return '遊戲釣獲';
      case FishDiscoveryStatus.verifiedRealCatch:
        return '真實捕獲';
    }
  }

  bool get showsBasicInfo =>
      this == FishDiscoveryStatus.gameCaught ||
      this == FishDiscoveryStatus.verifiedRealCatch;

  bool get showsFullInfo => this == FishDiscoveryStatus.verifiedRealCatch;

  bool get showsColorIcon =>
      this == FishDiscoveryStatus.gameCaught ||
      this == FishDiscoveryStatus.verifiedRealCatch;

  bool get showsName => this != FishDiscoveryStatus.unknown;

  static FishDiscoveryStatus fromStorage(String? value) {
    return FishDiscoveryStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => FishDiscoveryStatus.unknown,
    );
  }
}

class PlayerFishCollectionEntry {
  const PlayerFishCollectionEntry({
    required this.fishId,
    required this.status,
    this.firstEncounteredAt,
    this.firstGameCaughtAt,
    this.firstRealCaughtAt,
    this.realCatchPhotoPath,
    this.bestLengthCm,
    this.catchLatitude,
    this.catchLongitude,
  });

  final String fishId;
  final FishDiscoveryStatus status;
  final DateTime? firstEncounteredAt;
  final DateTime? firstGameCaughtAt;
  final DateTime? firstRealCaughtAt;
  final String? realCatchPhotoPath;
  final double? bestLengthCm;
  final double? catchLatitude;
  final double? catchLongitude;

  bool get showsPhotoProofBadge =>
      status == FishDiscoveryStatus.verifiedRealCatch &&
      realCatchPhotoPath != null &&
      realCatchPhotoPath!.trim().isNotEmpty;

  Map<String, dynamic> toMap() => {
        'fishId': fishId,
        'status': status.storageValue,
        'firstEncounteredAt': firstEncounteredAt?.toIso8601String(),
        'firstGameCaughtAt': firstGameCaughtAt?.toIso8601String(),
        'firstRealCaughtAt': firstRealCaughtAt?.toIso8601String(),
        'realCatchPhotoPath': realCatchPhotoPath,
        'bestLengthCm': bestLengthCm,
        'catchLatitude': catchLatitude,
        'catchLongitude': catchLongitude,
      };

  factory PlayerFishCollectionEntry.fromMap(Map<dynamic, dynamic> raw) {
    final map = Map<String, dynamic>.from(raw);
    DateTime? parseDate(String key) {
      final value = map[key] as String?;
      if (value == null || value.isEmpty) return null;
      return DateTime.tryParse(value);
    }

    return PlayerFishCollectionEntry(
      fishId: map['fishId'] as String,
      status: FishDiscoveryStatusX.fromStorage(map['status'] as String?),
      firstEncounteredAt: parseDate('firstEncounteredAt'),
      firstGameCaughtAt: parseDate('firstGameCaughtAt'),
      firstRealCaughtAt: parseDate('firstRealCaughtAt'),
      realCatchPhotoPath: map['realCatchPhotoPath'] as String?,
      bestLengthCm: (map['bestLengthCm'] as num?)?.toDouble(),
      catchLatitude: (map['catchLatitude'] as num?)?.toDouble(),
      catchLongitude: (map['catchLongitude'] as num?)?.toDouble(),
    );
  }

  PlayerFishCollectionEntry copyWith({
    FishDiscoveryStatus? status,
    DateTime? firstEncounteredAt,
    DateTime? firstGameCaughtAt,
    DateTime? firstRealCaughtAt,
    String? realCatchPhotoPath,
    double? bestLengthCm,
    double? catchLatitude,
    double? catchLongitude,
  }) {
    return PlayerFishCollectionEntry(
      fishId: fishId,
      status: status ?? this.status,
      firstEncounteredAt: firstEncounteredAt ?? this.firstEncounteredAt,
      firstGameCaughtAt: firstGameCaughtAt ?? this.firstGameCaughtAt,
      firstRealCaughtAt: firstRealCaughtAt ?? this.firstRealCaughtAt,
      realCatchPhotoPath: realCatchPhotoPath ?? this.realCatchPhotoPath,
      bestLengthCm: bestLengthCm ?? this.bestLengthCm,
      catchLatitude: catchLatitude ?? this.catchLatitude,
      catchLongitude: catchLongitude ?? this.catchLongitude,
    );
  }
}
