import 'package:flutter_test/flutter_test.dart';

import 'package:fishergo/features/fish/domain/fish_catalog_view_model.dart';
import 'package:fishergo/features/fish/domain/fish_collection_status.dart';
import 'package:fishergo/features/fish/domain/fish_species.dart';

FishSpecies species(String id) => FishSpecies(
      id: id,
      commonNameZh: id,
      imageUrl: 'assets/fish/mobile_webp/$id.webp',
    );

void main() {
  final entries = {
    'fish-002': const PlayerFishCollectionEntry(
      fishId: 'fish-002',
      status: FishDiscoveryStatus.gameCaught,
    ),
    'fish-003': const PlayerFishCollectionEntry(
      fishId: 'fish-003',
      status: FishDiscoveryStatus.verifiedRealCatch,
    ),
  };

  test('sorts the encyclopedia by fish number', () {
    final sorted = FishCatalogViewModel.sortByNumber([
      species('fish-010'),
      species('fish-002'),
      species('fish-001'),
    ]);

    expect(sorted.map((fish) => fish.id), ['fish-001', 'fish-002', 'fish-010']);
  });

  test('filters unlocked and verified entries independently', () {
    final source = [
      species('fish-001'),
      species('fish-002'),
      species('fish-003')
    ];

    expect(
      FishCatalogViewModel.filter(
        source,
        entries,
        FishCatalogFilter.unlocked,
      ).map((fish) => fish.id),
      ['fish-002', 'fish-003'],
    );
    expect(
      FishCatalogViewModel.filter(
        source,
        entries,
        FishCatalogFilter.verified,
      ).map((fish) => fish.id),
      ['fish-003'],
    );
  });

  test('reports only known game states as unlocked', () {
    expect(
      FishCatalogViewModel.isUnlocked(
        entries['fish-002']!,
      ),
      isTrue,
    );
    expect(
      FishCatalogViewModel.isUnlocked(
        const PlayerFishCollectionEntry(
          fishId: 'fish-001',
          status: FishDiscoveryStatus.encountered,
        ),
      ),
      isFalse,
    );
  });
}
