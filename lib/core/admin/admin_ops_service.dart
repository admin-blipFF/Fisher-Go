import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/profile/data/profile_wallet_service.dart';
import '../config/supabase_config.dart';
import 'fishing_spot_content_draft.dart';

class AnalyticsRetentionCohort {
  const AnalyticsRetentionCohort({
    required this.cohortDate,
    required this.cohortSize,
    required this.day2Returners,
    required this.day7Returners,
    required this.day2Rate,
    required this.day7Rate,
  });

  final DateTime cohortDate;
  final int cohortSize;
  final int day2Returners;
  final int day7Returners;
  final double day2Rate;
  final double day7Rate;

  factory AnalyticsRetentionCohort.fromMap(Map<String, dynamic> map) {
    final date = DateTime.tryParse(map['cohort_date']?.toString() ?? '');
    if (date == null) {
      throw const FormatException('invalid analytics cohort date');
    }
    return AnalyticsRetentionCohort(
      cohortDate: date,
      cohortSize: (map['cohort_size'] as num?)?.toInt() ?? 0,
      day2Returners: (map['day_2_returners'] as num?)?.toInt() ?? 0,
      day7Returners: (map['day_7_returners'] as num?)?.toInt() ?? 0,
      day2Rate: (map['day_2_rate'] as num?)?.toDouble() ?? 0,
      day7Rate: (map['day_7_rate'] as num?)?.toDouble() ?? 0,
    );
  }
}

class AdminOpsService {
  const AdminOpsService._();

  static SupabaseClient get _client => Supabase.instance.client;

  static bool get _ready => SupabaseConfig.isConfigured;

  static Future<bool> isCurrentUserAdmin() async {
    if (!_ready || _client.auth.currentSession == null) return false;
    try {
      final result = await _client.rpc('is_admin');
      return result == true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> createAnnouncement({
    required String title,
    required String body,
    required int coinReward,
    DateTime? endsAt,
  }) async {
    await _client.from('admin_announcements').insert({
      'title': title,
      'body': body,
      'coin_reward': coinReward,
      'ends_at': endsAt?.toIso8601String(),
      'created_by': _client.auth.currentUser?.id,
    });
  }

  static Future<void> createEvent({
    required String title,
    required String description,
    String? fishId,
    required String fishName,
    required double multiplier,
    DateTime? endsAt,
  }) async {
    final event = await _client
        .from('admin_events')
        .insert({
          'title': title,
          'description': description,
          'ends_at': endsAt?.toIso8601String(),
          'created_by': _client.auth.currentUser?.id,
        })
        .select('id')
        .single();

    await _client.from('fish_rate_boosts').insert({
      'event_id': event['id'],
      // Keep the stable catalog id alongside the legacy display label. The
      // client uses the id for spawn matching; the label remains useful for
      // older rows and admin inspection.
      'fish_id': fishId?.trim().isEmpty == true ? null : fishId?.trim(),
      'fish_name': fishName,
      'multiplier': multiplier,
      'ends_at': endsAt?.toIso8601String(),
      'created_by': _client.auth.currentUser?.id,
    });
  }

  static Future<void> grantCoins({
    required int amount,
    required String reason,
    String? targetEmail,
  }) async {
    await _client.from('coin_grants').insert({
      'target_email': targetEmail?.trim().isEmpty == true ? null : targetEmail,
      'amount': amount,
      'reason': reason,
      'created_by': _client.auth.currentUser?.id,
    });
  }

  /// Returns every fishing spot for the admin moderation surface.
  ///
  /// The database RLS policy is authoritative; this client-side check only
  /// avoids a request when the current session cannot be an admin.
  static Future<List<Map<String, dynamic>>>
      loadFishingSpotsForModeration() async {
    if (!_ready || _client.auth.currentSession == null) return const [];
    if (!await isCurrentUserAdmin()) return const [];

    final rows = await _client
        .from('fishing_spots')
        .select()
        .order('name_zh', ascending: true);
    return [
      for (final row in rows) Map<String, dynamic>.from(row as Map),
    ];
  }

  /// Updates only the moderation fields exposed by the admin console.
  static Future<void> moderateFishingSpot({
    required String id,
    required bool active,
    required String verificationStatus,
    required bool publicAccess,
  }) async {
    const allowedStatuses = {
      'draft',
      'communityReported',
      'verified',
      'suspended',
    };
    if (!allowedStatuses.contains(verificationStatus)) {
      throw ArgumentError.value(
        verificationStatus,
        'verificationStatus',
        'Unknown fishing spot moderation status',
      );
    }
    if (!_ready || _client.auth.currentSession == null) {
      throw StateError('Admin moderation requires an authenticated session');
    }

    await _client.from('fishing_spots').update({
      'active': active,
      'verification_status': verificationStatus,
      'public_access': publicAccess,
      'reviewer': _client.auth.currentUser?.email ??
          _client.auth.currentUser?.id ??
          'admin',
      'reviewed_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  /// Updates only the auditable habitat and spawn-weight content of a spot.
  ///
  /// The client validates the compact editor payload for fast feedback; the
  /// database constraints and admin RLS remain authoritative.
  static Future<void> updateFishingSpotContent({
    required String id,
    required Iterable<String> habitatTags,
    required Map<String, num> speciesWeights,
  }) async {
    if (!_ready || _client.auth.currentSession == null) {
      throw StateError('Spot content editing requires an authenticated session');
    }
    if (!await isCurrentUserAdmin()) {
      throw StateError('Spot content editing requires an admin session');
    }

    final normalizedTags =
        FishingSpotContentDraft.normalizeHabitatTags(habitatTags);
    final normalizedWeights =
        FishingSpotContentDraft.normalizeSpeciesWeights(speciesWeights);
    await _client.from('fishing_spots').update({
      'habitat_tags': normalizedTags,
      'species_weights': normalizedWeights,
      'reviewer': _client.auth.currentUser?.email ??
          _client.auth.currentUser?.id ??
          'admin',
      'reviewed_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  /// Loads a bounded, admin-only queue of real-catch submissions. Photo paths
  /// never leave this service; the UI receives short-lived signed URLs only.
  static Future<List<Map<String, dynamic>>> loadCatchesForModeration() async {
    if (!_ready || _client.auth.currentSession == null) return const [];
    if (!await isCurrentUserAdmin()) return const [];

    final rows = await _client
        .from('catches')
        .select(
          'id,species_name,caught_at,is_real_catch_proof,moderation_status,'
          'moderation_reason,photo_storage_path',
        )
        .eq('is_real_catch_proof', true)
        .order('caught_at', ascending: false)
        .limit(50);

    return Future.wait([
      for (final raw in rows)
        _withSignedCatchPhoto(Map<String, dynamic>.from(raw as Map)),
    ]);
  }

  static Future<Map<String, dynamic>> _withSignedCatchPhoto(
    Map<String, dynamic> row,
  ) async {
    final path = row['photo_storage_path']?.toString().trim();
    if (path == null || path.isEmpty) return row..['photo_url'] = null;

    try {
      final url =
          await _client.storage.from('catch-photos').createSignedUrl(path, 600);
      return row..['photo_url'] = url;
    } catch (_) {
      return row..['photo_url'] = null;
    }
  }

  /// Changes only the server-owned moderation state of a real catch.
  static Future<void> moderateCatch({
    required String id,
    required String moderationStatus,
    String? reason,
  }) async {
    const allowedStatuses = {
      'pending',
      'approved',
      'rejected',
      'suspended',
    };
    if (!allowedStatuses.contains(moderationStatus)) {
      throw ArgumentError.value(
        moderationStatus,
        'moderationStatus',
        'Unknown catch moderation status',
      );
    }
    if (!_ready || _client.auth.currentSession == null) {
      throw StateError('Catch moderation requires an authenticated session');
    }

    await _client
        .from('catches')
        .update({
          'moderation_status': moderationStatus,
          'moderation_reason':
              reason?.trim().isEmpty == true ? null : reason?.trim(),
        })
        .eq('id', id)
        .eq('is_real_catch_proof', true);
  }

  static Future<Map<String, double>> activeFishBoosts() async {
    if (!_ready || _client.auth.currentSession == null) return const {};
    try {
      final rows = await _client.rpc('get_active_fishing_event_config');
      final boosts = <String, double>{};
      for (final row in (rows as List)) {
        final fishId = row['fish_id']?.toString().trim();
        final name = row['fish_name']?.toString().trim();
        final multiplier = (row['multiplier'] as num?)?.toDouble();
        if (multiplier == null || !multiplier.isFinite || multiplier <= 0) {
          continue;
        }
        if (fishId != null && fishId.isNotEmpty) {
          boosts[fishId] = (boosts[fishId] ?? 1.0) * multiplier;
        }
        if (name != null && name.isNotEmpty) {
          boosts[name] = (boosts[name] ?? 1.0) * multiplier;
        }
      }
      return boosts;
    } catch (_) {
      return const {};
    }
  }

  static Future<int> claimPendingCoinGrants() async {
    if (!_ready || _client.auth.currentSession == null) return 0;
    try {
      final result = await _client.rpc('claim_my_coin_grants');
      final amount = (result as num?)?.toInt() ?? 0;
      if (amount > 0) {
        // The RPC already credits player_profiles atomically. Refresh the
        // cloud balance for the local cache without applying the grant again.
        await ProfileWalletService.getCoins();
      }
      return amount;
    } catch (_) {
      return 0;
    }
  }

  static Future<List<AnalyticsRetentionCohort>> loadRetentionReport({
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    if (!_ready || _client.auth.currentSession == null) return const [];
    if (!await isCurrentUserAdmin()) return const [];

    final raw = await _client.rpc(
      'analytics_retention_report',
      params: {
        'p_from_date': _dateOnly(fromDate),
        'p_to_date': _dateOnly(toDate),
      },
    );
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((row) => AnalyticsRetentionCohort.fromMap(
              Map<String, dynamic>.from(row),
            ))
        .toList(growable: false);
  }

  static String _dateOnly(DateTime value) {
    final utc = value.toUtc();
    final month = utc.month.toString().padLeft(2, '0');
    final day = utc.day.toString().padLeft(2, '0');
    return '${utc.year}-$month-$day';
  }
}
