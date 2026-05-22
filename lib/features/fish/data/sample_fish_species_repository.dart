import '../domain/fish_species.dart';
import 'fish_species_repository.dart';
import 'sample_fish_species_data_source.dart';

class SampleFishSpeciesRepository implements FishSpeciesRepository {
  const SampleFishSpeciesRepository([
    this._samples = const SampleFishSpeciesDataSource(),
  ]);

  final SampleFishSpeciesDataSource _samples;

  @override
  Future<List<FishSpecies>> getSpecies({bool forceRefresh = false}) async {
    return _samples.loadSpecies();
  }
}
