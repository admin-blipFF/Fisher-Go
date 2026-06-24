import '../domain/fish_species.dart';

List<FishSpecies> sortFullSpeciesLibrary(List<FishSpecies> source) {
  final normalized = source
      .map((item) => item.copyWith(
            fishType: _fishType(item),
            bodyShape: _bodyShape(item),
            rarityRank: _rarity(item),
          ))
      .toList();

  normalized.sort((a, b) {
    final typeCompare = (a.fishType ?? '').compareTo(b.fishType ?? '');
    if (typeCompare != 0) return typeCompare;

    final shapeCompare = (a.bodyShape ?? '').compareTo(b.bodyShape ?? '');
    if (shapeCompare != 0) return shapeCompare;

    final rarityCompare = b.rarityRank.compareTo(a.rarityRank);
    if (rarityCompare != 0) return rarityCompare;

    final numberA = _sortNumber(a);
    final numberB = _sortNumber(b);
    final numberCompare = numberA.compareTo(numberB);
    if (numberCompare != 0) return numberCompare;

    return a.commonNameZh.compareTo(b.commonNameZh);
  });

  return normalized;
}

String _fishType(FishSpecies fish) {
  if ((fish.fishType ?? '').isNotEmpty) return fish.fishType!;
  final text =
      '${fish.family ?? ''} ${fish.commonNameZh} ${fish.commonNameEn ?? ''}'
          .toLowerCase();

  if (text.contains('scaridae') || text.contains('parrot')) return '礁棲魚類';
  if (text.contains('serranidae') || text.contains('grouper')) return '礁棲魚類';
  if (text.contains('scorpaenidae') ||
      text.contains('lionfish') ||
      text.contains('stonefish')) {
    return '礁棲魚類';
  }
  if (text.contains('carangidae') ||
      text.contains('scad') ||
      text.contains('trevally')) {
    return '洄游掠食魚類';
  }
  if (text.contains('sparidae') || text.contains('seabream')) return '鯛科魚類';
  if (text.contains('siganidae') || text.contains('rabbitfish')) {
    return '近岸草食魚類';
  }
  if (text.contains('mugil') || text.contains('mullet')) return '近岸底層魚類';
  if (text.contains('catfish')) return '近岸底層魚類';

  return '其他魚類';
}

String _bodyShape(FishSpecies fish) {
  if ((fish.bodyShape ?? '').isNotEmpty) return fish.bodyShape!;
  final text =
      '${fish.family ?? ''} ${fish.commonNameZh} ${fish.commonNameEn ?? ''}'
          .toLowerCase();

  if (text.contains('needlefish') ||
      text.contains('eel') ||
      text.contains('belt')) {
    return '細長流線型';
  }
  if (text.contains('flatfish') || text.contains('sole')) return '扁平貼底型';
  if (text.contains('puffer') || text.contains('boxfish')) return '圓筒膨脹型';
  if (text.contains('lionfish') ||
      text.contains('scorpion') ||
      text.contains('stonefish')) {
    return '扇形棘鰭型';
  }
  if (text.contains('grouper')) return '粗壯紡錘型';
  if (text.contains('seabream') ||
      text.contains('rabbitfish') ||
      text.contains('damselfish')) {
    return '高身側扁型';
  }

  return '標準紡錘型';
}

int _rarity(FishSpecies fish) {
  if (fish.rarityRank > 1) return fish.rarityRank;

  switch (fish.dangerLevel) {
    case 'high':
      return 5;
    case 'medium':
      return 3;
    case 'low':
      return 2;
    default:
      return 1;
  }
}

int _sortNumber(FishSpecies fish) {
  final fromId = RegExp(r'(\d+)').firstMatch(fish.id)?.group(1);
  if (fromId != null) return int.tryParse(fromId) ?? 999999;

  final fromAfcd = RegExp(r'(\d+)').firstMatch(fish.afcdId ?? '')?.group(1);
  if (fromAfcd != null) return int.tryParse(fromAfcd) ?? 999999;

  final fromImage = RegExp(r'(\d+)').firstMatch(fish.imageUrl ?? '')?.group(1);
  if (fromImage != null) return int.tryParse(fromImage) ?? 999999;

  return 999999;
}
