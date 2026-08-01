import '../domain/fish_species.dart';
import 'fish_species_repository.dart';
import 'local_fish_species_data_source.dart';
import 'remote_fish_species_data_source.dart';
import 'sample_fish_species_data_source.dart';
import 'fish_species_sorting.dart';

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
    final cached = await _local.loadSpecies();
    final sampleCount = _samples.loadSpecies().length;

    // Return cache only if it has the full dataset
    if (!forceRefresh && cached.isNotEmpty && cached.length >= sampleCount) {
      return sortFullSpeciesLibrary(cached);
    }

    try {
      final remoteSpecies = await _remote.fetchSpecies();
      if (remoteSpecies.isNotEmpty) {
        final sorted = sortFullSpeciesLibrary(
          _mergeBundledSamples(remoteSpecies, _samples.loadSpecies()),
        );
        await _local.saveSpecies(sorted);
        return sorted;
      }
    } catch (_) {
      // Remote failed — fall through to bundled samples, NOT stale cache.
    }

    // Use bundled samples (153) rather than stale local cache (may be 126).
    final sampleSpecies = sortFullSpeciesLibrary(_samples.loadSpecies());
    await _local.saveSpecies(sampleSpecies);
    return sampleSpecies;
  }
}

List<FishSpecies> _mergeBundledSamples(
  List<FishSpecies> remoteSpecies,
  List<FishSpecies> bundledSamples,
) {
  final byId = <String, FishSpecies>{
    for (final fish in bundledSamples) fish.id: fish,
    for (final fish in remoteSpecies)
      fish.id: _preferLocalDisplayName(fish, bundledSamples),
  };
  return byId.values.toList(growable: false);
}

FishSpecies _preferLocalDisplayName(
  FishSpecies remoteFish,
  List<FishSpecies> bundledSamples,
) {
  FishSpecies? bundled;
  for (final sample in bundledSamples) {
    if (sample.id == remoteFish.id) {
      bundled = sample;
      break;
    }
  }

  if (bundled == null) return remoteFish;

  return remoteFish.copyWith(
    localNameZh: remoteFish.localNameZh?.trim().isNotEmpty == true
        ? remoteFish.localNameZh
        : bundled.localNameZh,
    imageUrl: remoteFish.imageUrl?.trim().isNotEmpty == true
        ? remoteFish.imageUrl
        : bundled.imageUrl,
    silhouetteUrl: remoteFish.silhouetteUrl?.trim().isNotEmpty == true
        ? remoteFish.silhouetteUrl
        : bundled.silhouetteUrl,
  );
}
