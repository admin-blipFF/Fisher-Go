import 'package:hive/hive.dart';

import '../domain/fish_species.dart';
import 'fish_species_sorting.dart';

class LocalFishSpeciesDataSource {
  static const _boxName = 'fish_species_cache';

  Future<Box> _box() => Hive.openBox(_boxName);

  Future<void> saveSpecies(List<FishSpecies> species) async {
    try {
      final box = await _box();
      await box.put('items', species.map((item) => item.toMap()).toList());
    } catch (_) {
      // Hive can be unavailable in widget tests or unsupported contexts.
      // The repository will still fall back to sample data.
    }
  }

  Future<List<FishSpecies>> loadSpecies() async {
    try {
      final box = await _box();
      final rawItems = box.get('items', defaultValue: <dynamic>[]) as List;
      final loaded = rawItems
          .cast<Map>()
          .map((item) => FishSpecies.fromMap(Map<String, dynamic>.from(item)))
          .toList();
      return sortFullSpeciesLibrary(loaded);
    } catch (_) {
      return const [];
    }
  }
}
