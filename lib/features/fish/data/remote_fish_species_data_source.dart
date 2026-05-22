import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../domain/fish_species.dart';

class RemoteFishSpeciesDataSource {
  RemoteFishSpeciesDataSource(this._client);

  final SupabaseClient _client;

  Future<List<FishSpecies>> fetchSpecies() async {
    if (!SupabaseConfig.isConfigured) {
      throw StateError('Supabase is not configured for this environment.');
    }

    final rows =
        await _client.from('fish_species').select().order('common_name_zh');
    return rows.map((row) => FishSpecies.fromMap(row)).toList();
  }
}
