import 'package:fishergo/features/game_home/domain/fishing_biome_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FishingBiomeRules', () {
    test('infers bridge and inner sea biomes from Hong Kong spot names', () {
      expect(
        FishingBiomeRules.inferSpotBiome(spotName: '青馬大橋橋底'),
        FishingSpotBiome.bridge,
      );
      expect(
        FishingBiomeRules.inferSpotBiome(spotName: '三門仔村碼頭'),
        FishingSpotBiome.innerSea,
      );
      expect(
        FishingBiomeRules.inferSpotBiome(spotName: '大埔內海'),
        FishingSpotBiome.innerSea,
      );
    });

    test('infers reef, rock, pier, boat, and island biomes', () {
      expect(
        FishingBiomeRules.inferSpotBiome(spotName: '德己利士礁', isIsland: true),
        FishingSpotBiome.reef,
      );
      expect(
        FishingBiomeRules.inferSpotBiome(spotName: '九龍石', isIsland: true),
        FishingSpotBiome.rock,
      );
      expect(
        FishingBiomeRules.inferSpotBiome(spotName: '中環碼頭'),
        FishingSpotBiome.pier,
      );
      expect(
        FishingBiomeRules.inferSpotBiome(spotName: '船家秘密釣點', isBoat: true),
        FishingSpotBiome.boat,
      );
      expect(
        FishingBiomeRules.inferSpotBiome(spotName: '東龍洲', isIsland: true),
        FishingSpotBiome.island,
      );
    });

    test('labels biomes for the spot card', () {
      expect(FishingBiomeRules.labelFor(FishingSpotBiome.bridge), '橋底水域');
      expect(FishingBiomeRules.labelFor(FishingSpotBiome.innerSea), '內海泥底');
      expect(FishingBiomeRules.labelFor(FishingSpotBiome.reef), '礁石水域');
    });

    test('uses key Hong Kong landmark backdrops for spot cards', () {
      expect(
        FishingBiomeRules.backdropAssetFor(
          spotName: '青馬大橋橋底',
          biome: FishingSpotBiome.bridge,
        ),
        'assets/fishing/spot_tsing_ma_bridge.png',
      );
      expect(
        FishingBiomeRules.backdropAssetFor(
          spotName: '馬灣碼頭',
          biome: FishingSpotBiome.bridge,
        ),
        'assets/fishing/spot_tsing_ma_bridge.png',
      );
      expect(
        FishingBiomeRules.backdropAssetFor(
          spotName: '中環碼頭',
          biome: FishingSpotBiome.pier,
        ),
        'assets/minigame/scene_pier.webp',
      );
      expect(
        FishingBiomeRules.backdropAssetFor(
          spotName: '三門仔村碼頭',
          biome: FishingSpotBiome.innerSea,
        ),
        'assets/fishing/spot_inner_sea.png',
      );
      expect(
        FishingBiomeRules.backdropAssetFor(
          spotName: '淺水灣泳灘',
          biome: FishingSpotBiome.beach,
        ),
        'assets/fishing/spot_beach.png',
      );
      expect(
        FishingBiomeRules.backdropAssetFor(
          spotName: '東龍洲',
          biome: FishingSpotBiome.island,
        ),
        'assets/fishing/spot_island.png',
      );
      expect(
        FishingBiomeRules.backdropAssetFor(
          spotName: '德己利士礁',
          biome: FishingSpotBiome.reef,
        ),
        'assets/fishing/spot_reef.png',
      );
      expect(
        FishingBiomeRules.backdropAssetFor(
          spotName: '九龍石',
          biome: FishingSpotBiome.rock,
        ),
        'assets/fishing/spot_rock.png',
      );
    });

    test('applies biome spawn multipliers without making generic fish vanish',
        () {
      expect(
        FishingBiomeRules.spawnMultiplier(
          biome: FishingSpotBiome.bridge,
          fishName: '海塘蝨',
          fishId: 'fish-069',
        ),
        greaterThan(1),
      );
      expect(
        FishingBiomeRules.spawnMultiplier(
          biome: FishingSpotBiome.innerSea,
          fishName: '烏頭',
          fishId: 'fish-063',
        ),
        greaterThan(1),
      );
      expect(
        FishingBiomeRules.spawnMultiplier(
          biome: FishingSpotBiome.pier,
          fishName: '藍鰭鮪',
          fishId: 'fish-153',
        ),
        1,
      );
    });
  });
}
