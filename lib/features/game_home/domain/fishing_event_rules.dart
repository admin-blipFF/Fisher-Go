import 'dart:collection';

enum FishingTimeWindow {
  morning,
  daytime,
  dusk,
  night,
}

class FishingEventRules {
  static const double tsingMaNightMultiplier = 2.0;
  static const double eastWaterDuskMultiplier = 1.8;
  static const double innerSeaMorningMultiplier = 1.8;
  static const double runwayBreamMultiplier = 1.6;

  const FishingEventRules._();

  static FishingTimeWindow timeWindowFor(DateTime now) {
    final hour = now.hour;

    if (hour >= 5 && hour < 10) return FishingTimeWindow.morning;
    if (hour >= 10 && hour < 17) return FishingTimeWindow.daytime;
    if (hour >= 17 && hour < 20) return FishingTimeWindow.dusk;

    return FishingTimeWindow.night;
  }

  static List<String> activeEventLabels({
    required String spotName,
    required DateTime now,
  }) {
    final spot = _normalize(spotName);
    final window = timeWindowFor(now);
    final labels = <String>[];

    if (_isTsingMaWater(spot) && window == FishingTimeWindow.night) {
      labels.add('夜水：石斑 / 海塘蝨提升');
    }
    if (_isEastWater(spot) && window == FishingTimeWindow.dusk) {
      labels.add('黃昏：池仔 / 黃雞魚提升');
    }
    if (_isInnerSea(spot) && window == FishingTimeWindow.morning) {
      labels.add('早水：烏頭提升');
    }
    if (_isRunwayOrNorthWater(spot) &&
        (window == FishingTimeWindow.morning ||
            window == FishingTimeWindow.dusk)) {
      labels.add('早晚：立魚提升');
    }

    return List.unmodifiable(LinkedHashSet<String>.from(labels));
  }

  static double eventMultiplier({
    required String spotName,
    required String fishName,
    String? fishId,
    required DateTime now,
  }) {
    final spot = _normalize(spotName);
    final fish = _normalize('$fishName ${fishId ?? ''}');
    final window = timeWindowFor(now);

    if (_isTsingMaWater(spot) &&
        window == FishingTimeWindow.night &&
        (_isGrouper(fish) || _isCatfish(fish))) {
      return tsingMaNightMultiplier;
    }
    if (_isEastWater(spot) &&
        window == FishingTimeWindow.dusk &&
        (_isScad(fish) ||
            _isCroaker(fish) ||
            _isChickenFish(fish) ||
            _isRedBream(fish))) {
      return eastWaterDuskMultiplier;
    }
    if (_isInnerSea(spot) &&
        window == FishingTimeWindow.morning &&
        _isMullet(fish)) {
      return innerSeaMorningMultiplier;
    }
    if (_isRunwayOrNorthWater(spot) &&
        (window == FishingTimeWindow.morning ||
            window == FishingTimeWindow.dusk) &&
        _isBream(fish)) {
      return runwayBreamMultiplier;
    }

    return 1.0;
  }

  static String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'\s+'), '');

  static bool _hasAny(String value, List<String> keywords) =>
      keywords.any(value.contains);

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

  static bool _isInnerSea(String spot) => _hasAny(spot, const [
        '三門仔',
        '大埔',
        '吐露港',
        '大美督',
        '船灣',
        '馬屎洲',
        '內海',
      ]);

  static bool _isRunwayOrNorthWater(String spot) => _hasAny(spot, const [
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
        '東涌',
        '赤鱲角',
        '機場',
        '跑道',
        '三跑',
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

  static bool _isRedBream(String fish) => _hasAny(fish, const [
        '赤鱲',
        '赤立',
        '紅鱲',
        'fish-102',
        'fish-103',
        'fish-110',
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

  static bool _isScad(String fish) => _hasAny(fish, const [
        '池仔',
        '池魚',
        '真池魚',
        '深海沙丁',
        'scad',
        'fish-131',
        'fish-135',
      ]);

  static bool _isCroaker(String fish) => _hasAny(fish, const [
        '惑魚',
        '或魚',
        'fish-126',
      ]);

  static bool _isChickenFish(String fish) => _hasAny(fish, const [
        '雞魚',
        '黃雞魚',
        '花雞',
        'fish-101',
      ]);
}
