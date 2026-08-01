import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';

class PublicLeaderboardEntry {
  const PublicLeaderboardEntry({
    this.speciesId,
    required this.speciesName,
    this.lengthCm,
    this.verifiedAt,
    required this.score,
  });

  final String? speciesId;
  final String speciesName;
  final double? lengthCm;
  final DateTime? verifiedAt;
  final int score;

  factory PublicLeaderboardEntry.fromMap(Map<String, dynamic> map) {
    final rawVerifiedAt = map['verified_at'];
    final verifiedAt = rawVerifiedAt is DateTime
        ? rawVerifiedAt
        : rawVerifiedAt is String
            ? DateTime.tryParse(rawVerifiedAt)
            : null;
    final rawSpeciesName = map['species_name']?.toString().trim() ?? '';

    return PublicLeaderboardEntry(
      speciesId: map['species_id']?.toString().trim().isEmpty == true
          ? null
          : map['species_id']?.toString(),
      speciesName: rawSpeciesName.isEmpty ? '未知魚種' : rawSpeciesName,
      lengthCm: (map['length_cm'] as num?)?.toDouble(),
      verifiedAt: verifiedAt,
      score: (map['score'] as num?)?.toInt() ?? 1,
    );
  }
}

class PublicLeaderboardSnapshot {
  const PublicLeaderboardSnapshot({
    required this.remoteAvailable,
    required this.entries,
  });

  const PublicLeaderboardSnapshot.unavailable()
      : remoteAvailable = false,
        entries = const [];

  final bool remoteAvailable;
  final List<PublicLeaderboardEntry> entries;
}

class PublicLeaderboardService {
  const PublicLeaderboardService._();

  static Future<PublicLeaderboardSnapshot> load({
    int windowDays = 7,
    int limit = 50,
  }) async {
    if (!SupabaseConfig.isConfigured) {
      return const PublicLeaderboardSnapshot.unavailable();
    }

    final client = Supabase.instance.client;
    if (client.auth.currentSession == null) {
      return const PublicLeaderboardSnapshot.unavailable();
    }

    try {
      final raw = await client.rpc(
        'get_public_leaderboard',
        params: {
          'window_days': windowDays,
          'limit_count': limit,
        },
      );
      if (raw is! List) return const PublicLeaderboardSnapshot.unavailable();

      return PublicLeaderboardSnapshot(
        remoteAvailable: true,
        entries: [
          for (final row in raw)
            if (row is Map)
              PublicLeaderboardEntry.fromMap(
                Map<String, dynamic>.from(row),
              ),
        ],
      );
    } catch (_) {
      return const PublicLeaderboardSnapshot.unavailable();
    }
  }
}
