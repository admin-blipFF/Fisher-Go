import '../domain/fish_species.dart';

abstract class FishSpeciesRepository {
  Future<List<FishSpecies>> getSpecies({bool forceRefresh = false});
}
