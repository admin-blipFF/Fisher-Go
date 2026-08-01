import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fishergo/features/fish/data/offline_first_fish_species_repository.dart';
import 'package:fishergo/features/fish/data/local_fish_species_data_source.dart';
import 'package:fishergo/features/fish/data/remote_fish_species_data_source.dart';
import 'package:fishergo/features/fish/data/sample_fish_species_data_source.dart';
import 'package:fishergo/features/fish/domain/fish_species.dart';

class _FakeRemote extends RemoteFishSpeciesDataSource {
  _FakeRemote(this.rows)
      : super(SupabaseClient('https://example.supabase.co', 'anon-key'));

  final List<FishSpecies> rows;

  @override
  Future<List<FishSpecies>> fetchSpecies() async => rows;
}

class _MemoryLocal extends LocalFishSpeciesDataSource {
  List<FishSpecies> rows = const [];

  @override
  Future<List<FishSpecies>> loadSpecies() async => rows;

  @override
  Future<void> saveSpecies(List<FishSpecies> species) async {
    rows = species;
  }
}

void main() {
  test('remote generated fish paths resolve to the compressed mobile bundle',
      () {
    final fish = FishSpecies.fromMap({
      'id': 'fish-001',
      'common_name_zh': '黃腳鱲',
      'image_url':
          'assets/fish/icons/generated/001_hk-yellowfin-seabream-badge.png',
    });

    expect(
      fish.imageUrl,
      'assets/fish/mobile_webp/001_hk-yellowfin-seabream-badge.webp',
    );
  });

  test('game artwork resolves badge paths to transparent mobile art', () {
    expect(
      fishGameArtworkAssetPath(
        'assets/fish/icons/generated/003_hk-goldlined-seabream-badge.png',
      ),
      'assets/fish/mobile_webp/003_hk-goldlined-seabream.webp',
    );
  });

  test('game artwork resolves local badge paths to numbered transparent art',
      () {
    expect(
      fishGameArtworkAssetPath(
        'assets/fish/icons/generated/059_hk-goatfish-local-badge.png',
      ),
      'assets/fish/mobile_webp/059.webp',
    );
  });

  test('fish display name uses local name first', () {
    const fish = FishSpecies(
      id: 'fish-126',
      commonNameZh: '鯔魚',
      localNameZh: '烏頭',
    );

    expect(fish.displayLocalName, '烏頭');
    expect(fish.displayNameLocalSlashCommon, '烏頭｜鯔魚');
  });

  test(
      'remote catalog is merged with bundled samples so fish 126 and 127 exist',
      () async {
    final local = _MemoryLocal();
    final repo = OfflineFirstFishSpeciesRepository(
      remote: _FakeRemote(const [
        FishSpecies(id: 'fish-001', commonNameZh: '遠端魚'),
      ]),
      local: local,
      samples: const SampleFishSpeciesDataSource(),
    );

    final species = await repo.getSpecies(forceRefresh: true);
    final ids = species.map((fish) => fish.id).toSet();

    expect(ids, contains('fish-126'));
    expect(ids, contains('fish-127'));
    expect(species.firstWhere((fish) => fish.id == 'fish-126').displayLocalName,
        '黑咕咕');
    expect(species.firstWhere((fish) => fish.id == 'fish-127').displayLocalName,
        '花雞');
  });
}
