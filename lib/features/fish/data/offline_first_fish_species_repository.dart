import '../domain/fish_species.dart';
import 'fish_species_repository.dart';
import 'local_fish_species_data_source.dart';
import 'remote_fish_species_data_source.dart';
import 'sample_fish_species_data_source.dart';

class OfflineFirstFishSpeciesRepository implements FishSpeciesRepository {
  OfflineFirstFishSpeciesRepository({
    required RemoteFishSpeciesDataSource remote,
    required LocalFishSpeciesDataSource local,
    SampleFishSpeciesDataSource samples = const SampleFishSpeciesDataSource(),
  })  : _remote = remote,
        _local = local,
        _samples = samples;

  final RemoteFishSpeciesDataSource _remote;
  final LocalFishSpeciesDataSource _local;
  final SampleFishSpeciesDataSource _samples;

  @override
  Future<List<FishSpecies>> getSpecies({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await _local.loadSpecies();
      if (cached.isNotEmpty) return cached;
    }

    try {
      final remoteSpecies = await _remote.fetchSpecies();
      if (remoteSpecies.isNotEmpty) {
        await _local.saveSpecies(remoteSpecies);
        return remoteSpecies;
      }
    } catch (_) {
      // Web-first MVP: Supabase credentials are optional. Fall through to
      // local cache or bundled Hong Kong fish samples.
    }

    final cached = await _local.loadSpecies();
    if (cached.isNotEmpty) return cached;

    final sampleSpecies = _samples.loadSpecies();
    await _local.saveSpecies(sampleSpecies);
    return sampleSpecies;
  }
}
