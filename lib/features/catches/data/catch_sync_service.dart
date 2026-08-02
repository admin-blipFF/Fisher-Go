import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/telemetry/app_telemetry.dart';
import 'catch_photo_storage.dart';
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

typedef CatchRowInserter = Future<void> Function(
  Map<String, dynamic> row,
);

class SupabaseCatchRemoteDataSource implements CatchRemoteDataSource {
  SupabaseCatchRemoteDataSource(
    this._client, {
    CatchPhotoUploader? photoUploader,
    CatchRowInserter? rowInserter,
  })  : _photoUploader = photoUploader ?? CatchPhotoStorage(_client),
        _rowInserter = rowInserter;

  final SupabaseClient _client;
  final CatchPhotoUploader _photoUploader;
  final CatchRowInserter? _rowInserter;

  @override
  Future<void> uploadCatch({
    required String userId,
    required CatchLogEntry entry,
  }) async {
    final stopwatch = Stopwatch()..start();
    unawaited(
      AppTelemetry.instance.record(
        TelemetryEventName.catchUpload,
        fields: {'proof': entry.isRealCatchProof, 'outcome': 'started'},
      ),
    );
    String? photoStoragePath;
    try {
      if (entry.isRealCatchProof && entry.photoPath != null) {
        photoStoragePath = await _photoUploader.upload(
          userId: userId,
          entry: entry,
        );
      }

      final row = <String, dynamic>{
        'user_id': userId,
        'species_id': _toNullableUuid(entry.speciesId),
        'species_name': entry.speciesName,
        'photo_url': null,
        'photo_storage_path': photoStoragePath,
        'local_photo_name': entry.photoPath,
        'latitude': entry.latitude,
        'longitude': entry.longitude,
        'caught_at': entry.caughtAt.toIso8601String(),
        'length_cm': entry.lengthCm,
        'weight_kg': entry.weightKg,
        'notes': entry.notes,
        'checkpoint_count': entry.checkpoints.length,
        'checkpoint_path': entry.checkpoints.map((e) => e.toMap()).toList(),
        'is_real_catch_proof': entry.isRealCatchProof,
        'recognition_confidence': entry.recognitionConfidence,
        'recognized_species_id': entry.recognizedSpeciesId,
        'verified_at': entry.verifiedAt?.toIso8601String(),
        'sync_status': 'synced',
        'score': 1,
        'is_new_species': false,
      };
      final rowInserter = _rowInserter;
      if (rowInserter != null) {
        await rowInserter(row);
      } else {
        await _client.from('catches').insert(row);
      }
      unawaited(
        AppTelemetry.instance.record(
          TelemetryEventName.catchUpload,
          fields: {
            'proof': entry.isRealCatchProof,
            'outcome': 'success',
            'durationMs': stopwatch.elapsedMilliseconds,
          },
        ),
      );
    } catch (_) {
      if (photoStoragePath != null) {
        try {
          await _photoUploader.delete(objectPath: photoStoragePath);
        } catch (_) {
          // Preserve the row-insert error; the next operational cleanup can
          // remove an orphaned object without losing the catch retry.
        }
      }
      unawaited(
        AppTelemetry.instance.record(
          TelemetryEventName.catchUpload,
          fields: {
            'proof': entry.isRealCatchProof,
            'outcome': 'failure',
            'durationMs': stopwatch.elapsedMilliseconds,
          },
        ),
      );
      rethrow;
    }
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
        _currentUserId = currentUserId ??
            (() => Supabase.instance.client.auth.currentUser?.id);

  final CatchRemoteDataSource _remote;
  final bool Function() _isConfigured;
  final String? Function() _currentUserId;

  Future<CatchSyncSummary> sync(List<CatchLogEntry> entries) async {
    final stopwatch = Stopwatch()..start();
    if (!_isConfigured()) {
      final summary = CatchSyncSummary(
        total: entries.length,
        synced: 0,
        failed: 0,
        skipped: entries.length,
        failedIds: const <String>{},
      );
      unawaited(
        _recordSync(summary, durationMs: stopwatch.elapsedMilliseconds),
      );
      return summary;
    }

    final userId = _currentUserId();
    if (userId == null) {
      final summary = CatchSyncSummary(
        total: entries.length,
        synced: 0,
        failed: 0,
        skipped: entries.length,
        failedIds: const <String>{},
      );
      unawaited(
        _recordSync(summary, durationMs: stopwatch.elapsedMilliseconds),
      );
      return summary;
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

    final summary = CatchSyncSummary(
      total: entries.length,
      synced: syncedCount,
      failed: failedIds.length,
      skipped: 0,
      failedIds: failedIds,
    );
    unawaited(
      _recordSync(summary, durationMs: stopwatch.elapsedMilliseconds),
    );
    return summary;
  }

  Future<void> _recordSync(
    CatchSyncSummary summary, {
    required int durationMs,
  }) {
    return AppTelemetry.instance.record(
      TelemetryEventName.catchSync,
      fields: {
        'total': summary.total,
        'synced': summary.synced,
        'failed': summary.failed,
        'skipped': summary.skipped,
        'durationMs': durationMs,
      },
    );
  }
}
