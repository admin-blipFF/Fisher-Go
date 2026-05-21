import 'package:hive/hive.dart';

import '../domain/fish_species.dart';

class LocalFishSpeciesDataSource {
  static const _boxName = 'fish_species_cache';

  Future<Box> _box() => Hive.openBox(_boxName);

  Future<void> saveSpecies(List<FishSpecies> species) async {
    final box = await _box();
    await box.put('items', species.map((item) => item.toMap()).toList());
  }

  Future<List<FishSpecies>> loadSpecies() async {
    final box = await _box();
    final rawItems = box.get('items', defaultValue: <dynamic>[]) as List;
    return rawItems
        .cast<Map>()
        .map((item) => FishSpecies.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }
}
