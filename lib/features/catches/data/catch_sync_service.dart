import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../domain/catch_log_entry.dart';

class CatchSyncSummary {
  const CatchSyncSummary({
    required this.total,
    required this.synced,
    required this.failed,
    required this.skipped,
    required this.failedIds,
  });

  final int total;
  final int synced;
  final int failed;
  final int skipped;
  final Set<String> failedIds;
}

abstract class CatchRemoteDataSource {
  Future<void> uploadCatch({
    required String userId,
    required CatchLogEntry entry,
  });
}

class SupabaseCatchRemoteDataSource implements CatchRemoteDataSource {
  SupabaseCatchRemoteDataSource(this._client);

  final SupabaseClient _client;

  @override
  Future<void> uploadCatch({
    required String userId,
    required CatchLogEntry entry,
  }) async {
    await _client.from('catches').insert({
      'user_id': userId,
      'species_id': _toNullableUuid(entry.speciesId),
      'species_name': entry.speciesName,
      'photo_url': entry.photoPath,
      'latitude': entry.latitude,
      'longitude': entry.longitude,
      'caught_at': entry.caughtAt.toIso8601String(),
      'checkpoint_count': entry.checkpoints.length,
      'checkpoint_path': entry.checkpoints.map((e) => e.toMap()).toList(),
      'sync_status': 'synced',
      'score': 1,
      'is_new_species': false,
    });
  }

  String? _toNullableUuid(String value) {
    final uuidPattern = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    );
    return uuidPattern.hasMatch(value) ? value : null;
  }
}

class CatchSyncService {
  CatchSyncService({
    required CatchRemoteDataSource remote,
    bool Function()? isConfigured,
    String? Function()? currentUserId,
  })  : _remote = remote,
        _isConfigured = isConfigured ?? (() => SupabaseConfig.isConfigured),
        _currentUserId =
            currentUserId ?? (() => Supabase.instance.client.auth.currentUser?.id);

  final CatchRemoteDataSource _remote;
  final bool Function() _isConfigured;
  final String? Function() _currentUserId;

  Future<CatchSyncSummary> sync(List<CatchLogEntry> entries) async {
    if (!_isConfigured()) {
      return CatchSyncSummary(
        total: entries.length,
        synced: 0,
        failed: 0,
        skipped: entries.length,
        failedIds: const <String>{},
      );
    }

    final userId = _currentUserId();
    if (userId == null) {
      return CatchSyncSummary(
        total: entries.length,
        synced: 0,
        failed: 0,
        skipped: entries.length,
        failedIds: const <String>{},
      );
    }

    var syncedCount = 0;
    final failedIds = <String>{};

    for (final entry in entries) {
      try {
        await _remote.uploadCatch(userId: userId, entry: entry);
        syncedCount += 1;
      } catch (_) {
        failedIds.add(entry.id);
      }
    }

    return CatchSyncSummary(
      total: entries.length,
      synced: syncedCount,
      failed: failedIds.length,
      skipped: 0,
      failedIds: failedIds,
    );
  }
}
