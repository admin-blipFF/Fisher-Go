enum FishingSpotBiome {
  pier,
  rock,
  reef,
  beach,
  boat,
  island,
  innerSea,
  bridge,
}

class FishingBiomeRules {
  const FishingBiomeRules._();

  static FishingSpotBiome inferSpotBiome({
    required String spotName,
    bool isIsland = false,
    bool isBoat = false,
  }) {
    final spot = _normalize(spotName);

    if (isBoat || _hasAny(spot, const ['船家', '船釣', 'boat'])) {
      return FishingSpotBiome.boat;
    }
    if (_hasAny(spot, const ['橋', '青馬', '汲水門', '長索'])) {
      return FishingSpotBiome.bridge;
    }
    if (_hasAny(spot, const ['三門仔', '大埔', '吐露港', '內海', '船灣', '大美督'])) {
      return FishingSpotBiome.innerSea;
    }
    if (_hasAny(spot, const ['礁', '珊瑚', 'reef'])) {
      return FishingSpotBiome.reef;
    }
    if (_hasAny(spot, const ['石', '排', 'rock'])) {
      return FishingSpotBiome.rock;
    }
    if (_hasAny(spot, const ['沙灘', '泳灘', '沙洲', 'beach'])) {
      return FishingSpotBiome.beach;
    }
    if (isIsland || _hasAny(spot, const ['洲', '島', '角'])) {
      return FishingSpotBiome.island;
    }
    return FishingSpotBiome.pier;
  }

  static String labelFor(FishingSpotBiome biome) => switch (biome) {
        FishingSpotBiome.pier => '碼頭近岸',
        FishingSpotBiome.rock => '岩礁石位',
        FishingSpotBiome.reef => '礁石水域',
        FishingSpotBiome.beach => '沙灘淺水',
        FishingSpotBiome.boat => '船釣水域',
        FishingSpotBiome.island => '離島外水',
        FishingSpotBiome.innerSea => '內海泥底',
        FishingSpotBiome.bridge => '橋底水域',
      };

  static String backdropAssetFor({
    required String spotName,
    required FishingSpotBiome biome,
  }) {
    final spot = _normalize(spotName);
    if (biome == FishingSpotBiome.bridge ||
        _hasAny(spot, const ['青馬', '馬灣', '青衣', '長索', '汲水門'])) {
      return 'assets/fishing/spot_tsing_ma_bridge.png';
    }
    return switch (biome) {
      FishingSpotBiome.island ||
      FishingSpotBiome.boat =>
        'assets/fishing/spot_island.png',
      FishingSpotBiome.reef => 'assets/fishing/spot_reef.png',
      FishingSpotBiome.rock => 'assets/fishing/spot_rock.png',
      FishingSpotBiome.innerSea => 'assets/fishing/spot_inner_sea.png',
      FishingSpotBiome.beach => 'assets/fishing/spot_beach.png',
      FishingSpotBiome.pier ||
      FishingSpotBiome.bridge =>
        'assets/minigame/scene_pier.webp',
    };
  }

  static double spawnMultiplier({
    required FishingSpotBiome biome,
    required String fishName,
    String? fishId,
  }) {
    final fish = _normalize('$fishName ${fishId ?? ''}');

    if (biome == FishingSpotBiome.bridge &&
        (_isGrouper(fish) || _isCatfish(fish))) {
      return 2.5;
    }
    if (biome == FishingSpotBiome.innerSea && _isMullet(fish)) {
      return 2.5;
    }
    if ((biome == FishingSpotBiome.reef || biome == FishingSpotBiome.rock) &&
        _isGrouper(fish)) {
      return 1.8;
    }
    if ((biome == FishingSpotBiome.island || biome == FishingSpotBiome.boat) &&
        (_isScad(fish) || _isBream(fish))) {
      return 1.6;
    }
    if (biome == FishingSpotBiome.pier && _isMullet(fish)) {
      return 1.25;
    }

    return 1;
  }

  static String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'\s+'), '');

  static bool _hasAny(String value, List<String> keywords) =>
      keywords.any(value.contains);

  static bool _isBream(String fish) => _hasAny(fish, const [
        '立',
        '鱲',
        '黃腳',
        '赤鱲',
        '紅鱲',
        'fish-096',
        'fish-097',
        'fish-099',
        'fish-100',
        'fish-102',
        'fish-103',
        'fish-109',
        'fish-110',
        'fish-111',
      ]);

  static bool _isMullet(String fish) => _hasAny(fish, const [
        '烏頭',
        '灰烏頭',
        '大眼烏頭',
        'fish-063',
        'fish-067',
      ]);

  static bool _isGrouper(String fish) => _hasAny(fish, const [
        '斑',
        '班',
        '石斑',
        '紅斑',
        '青斑',
        '龍躉',
        'grouper',
        'fish-072',
        'fish-073',
        'fish-074',
        'fish-075',
        'fish-076',
        'fish-077',
        'fish-078',
        'fish-079',
        'fish-080',
        'fish-081',
        'fish-082',
        'fish-083',
        'fish-084',
      ]);

  static bool _isCatfish(String fish) => _hasAny(fish, const [
        'catfish',
        '鯰',
        '鮎',
        '塘蝨',
        '海塘蝨',
        'fish-069',
        'fish-070',
      ]);

  static bool _isScad(String fish) => _hasAny(fish, const [
        '池仔',
        '池魚',
        '真池魚',
        '深海沙丁',
        'scad',
        'fish-131',
        'fish-135',
      ]);
}
