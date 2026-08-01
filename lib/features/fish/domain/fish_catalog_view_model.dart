import 'fish_collection_status.dart';
import 'fish_species.dart';

enum FishCatalogFilter { all, unlocked, verified }

class FishCatalogViewModel {
  const FishCatalogViewModel._();

  static List<FishSpecies> sortByNumber(Iterable<FishSpecies> source) {
    final sorted = source.toList(growable: false);
    final result = [...sorted];
    result.sort((a, b) {
      final numberCompare = _number(a.id).compareTo(_number(b.id));
      if (numberCompare != 0) return numberCompare;
      return a.displayLocalName.compareTo(b.displayLocalName);
    });
    return result;
  }

  static List<FishSpecies> filter(
    Iterable<FishSpecies> source,
    Map<String, PlayerFishCollectionEntry> collection,
    FishCatalogFilter filter,
  ) {
    return source.where((fish) {
      final status = collection[fish.id]?.status;
      return switch (filter) {
        FishCatalogFilter.all => true,
        FishCatalogFilter.unlocked => status != null &&
            status.index >= FishDiscoveryStatus.gameCaught.index,
        FishCatalogFilter.verified =>
          status == FishDiscoveryStatus.verifiedRealCatch,
      };
    }).toList(growable: false);
  }

  static bool isUnlocked(PlayerFishCollectionEntry entry) =>
      entry.status.index >= FishDiscoveryStatus.gameCaught.index;

  static int _number(String id) {
    final match = RegExp(r'(\d+)').firstMatch(id);
    return int.tryParse(match?.group(1) ?? '') ?? 999999;
  }
}
