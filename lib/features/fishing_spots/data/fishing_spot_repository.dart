import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/public_app_config.dart';
import '../../../core/config/supabase_config.dart';
import '../domain/fishing_spot.dart';
import 'fishing_spot_registry.dart';

class FishingSpotRepository {
  FishingSpotRepository({
    SupabaseClient? client,
    bool? remoteRegistryEnabled,
  })  : _client = client,
        _remoteRegistryEnabled =
            remoteRegistryEnabled ?? SupabaseConfig.isConfigured;

  final SupabaseClient? _client;
  final bool _remoteRegistryEnabled;

  Future<List<FishingSpot>> getActiveVerifiedSpots() async {
    if (!PublicAppConfig.fishingSpotsEnabled) return const [];
    final client = _client;
    if (_remoteRegistryEnabled) {
      if (client == null) return const [];
      try {
        final rows = await client
            .from('fishing_spots')
            .select()
            .eq('active', true)
            .eq('verification_status', 'verified')
            .eq('public_access', true);
        final remote = rows
            .map((row) => FishingSpot.fromMap(Map<String, dynamic>.from(row)))
            .where((spot) => spot.isPubliclyEligible)
            .toList(growable: false);
        // An empty remote registry is meaningful: do not repopulate it with
        // local points that may have been suspended remotely.
        return remote;
      } catch (_) {
        // A configured remote registry is authoritative. Returning no points
        // is safer than resurrecting a stale or suspended local coordinate.
        return const [];
      }
    }

    return loadBundledFishingSpotRegistry()
        .where((spot) => spot.isPubliclyEligible)
        .toList(growable: false);
  }
}
