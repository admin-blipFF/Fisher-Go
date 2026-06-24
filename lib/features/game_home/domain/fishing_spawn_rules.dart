import 'dart:collection';

import 'fishing_biome_rules.dart';

class FishingSpawnRules {
  static const double targetMultiplier = 4;

  const FishingSpawnRules._();

  static double locationMultiplier({
    required String spotName,
    required String fishName,
    String? fishId,
    FishingSpotBiome? biome,
  }) {
    final spot = _normalize(spotName);
    final fish = _normalize('$fishName ${fishId ?? ''}');
    final biomeMultiplier = biome == null
        ? 1.0
        : FishingBiomeRules.spawnMultiplier(
            biome: biome,
            fishName: fishName,
            fishId: fishId,
          );
    var isSpecialLocationFish = false;

    if (_isBream(fish) && (_isNorthWater(spot) || _isTungChungRunway(spot))) {
      return targetMultiplier * biomeMultiplier;
    }
    isSpecialLocationFish = isSpecialLocationFish || _isBream(fish);

    if (_isMullet(fish) && _isSamMunTsaiTaiPoInnerWater(spot)) {
      return targetMultiplier * biomeMultiplier;
    }
    isSpecialLocationFish = isSpecialLocationFish || _isMullet(fish);

    if ((_isGrouper(fish) || _isCatfish(fish)) && _isTsingMaWater(spot)) {
      return targetMultiplier * biomeMultiplier;
    }
    isSpecialLocationFish =
        isSpecialLocationFish || _isGrouper(fish) || _isCatfish(fish);

    if (_isEastWaterFish(fish) && _isEastWater(spot)) {
      return targetMultiplier * biomeMultiplier;
    }
    isSpecialLocationFish = isSpecialLocationFish || _isEastWaterFish(fish);

    if (isSpecialLocationFish) return 0;

    return biomeMultiplier;
  }

  static List<String> spotIntelLabels(String spotName) {
    final spot = _normalize(spotName);
    final labels = <String>[];

    if (_isNorthWater(spot) || _isTungChungRunway(spot)) {
      labels.addAll(const ['立魚', '黃腳鱲', '赤鱲']);
    }
    if (_isSamMunTsaiTaiPoInnerWater(spot)) {
      labels.addAll(const ['烏頭', '大眼烏頭']);
    }
    if (_isTsingMaWater(spot)) {
      labels.addAll(const ['石斑', '海塘蝨']);
    }
    if (_isEastWater(spot)) {
      labels.addAll(const ['池仔', '赤鱲', '黃雞魚']);
    }

    return List.unmodifiable(LinkedHashSet<String>.from(labels));
  }

  static String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'\s+'), '');

  static bool _hasAny(String value, List<String> keywords) =>
      keywords.any(value.contains);

  static bool _isNorthWater(String spot) => _hasAny(spot, const [
        '北水',
        '塔門',
        '東平洲',
        '鴨洲',
        '吉澳',
        '印洲塘',
        '沙頭角',
        '赤門',
        '大鵬',
        '馬屎洲',
      ]);

  static bool _isTungChungRunway(String spot) => _hasAny(spot, const [
        '東涌',
        '赤鱲角',
        '機場',
        '跑道',
        '三跑',
      ]);

  static bool _isSamMunTsaiTaiPoInnerWater(String spot) => _hasAny(spot, const [
        '三門仔',
        '大埔',
        '吐露港',
        '大美督',
        '船灣',
        '馬屎洲',
        '內海',
      ]);

  static bool _isTsingMaWater(String spot) => _hasAny(spot, const [
        '青馬',
        '青衣',
        '馬灣',
        '汲水門',
        '藍巴勒',
        '荃灣',
        '深井',
        '長索',
      ]);

  static bool _isEastWater(String spot) => _hasAny(spot, const [
        '東水',
        '東龍',
        '東平洲',
        '果洲',
        '伙頭墳洲',
        '牛尾洲',
        '滘西洲',
        '破邊洲',
        '蒲台',
        '清水灣',
        '西貢',
        '將軍澳',
      ]);

  static bool _isBream(String fish) => _hasAny(fish, const [
        '立',
        '鱲',
        '黃腳',
        '赤鱲',
        '紅鱲',
        '黑沙鱲',
        '烏頭鱲',
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
        '草魚',
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

  static bool _isEastWaterFish(String fish) => _hasAny(fish, const [
        '惑魚',
        '或魚',
        '池仔',
        '池魚',
        '真池魚',
        '深海沙丁',
        '赤鱲',
        '赤立',
        '紅鱲',
        '雞魚',
        '黃雞魚',
        '花雞',
        'fish-101',
        'fish-102',
        'fish-103',
        'fish-126',
        'fish-131',
        'fish-135',
      ]);
}
