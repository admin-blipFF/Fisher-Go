import '../domain/fish_species.dart';
import 'fish_species_repository.dart';
import 'local_fish_species_data_source.dart';
import 'remote_fish_species_data_source.dart';

class OfflineFirstFishSpeciesRepository implements FishSpeciesRepository {
  OfflineFirstFishSpeciesRepository({
    required RemoteFishSpeciesDataSource remote,
    required LocalFishSpeciesDataSource local,
  })  : _remote = remote,
        _local = local;

  final RemoteFishSpeciesDataSource _remote;
  final LocalFishSpeciesDataSource _local;

  @override
  Future<List<FishSpecies>> getSpecies({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await _local.loadSpecies();
      if (cached.isNotEmpty) return cached;
    }

    try {
      final remoteSpecies = await _remote.fetchSpecies();
      await _local.saveSpecies(remoteSpecies);
      return remoteSpecies;
    } catch (_) {
      return _local.loadSpecies();
    }
  }
}
