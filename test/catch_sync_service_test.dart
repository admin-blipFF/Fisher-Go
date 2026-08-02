import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:fishergo/features/catches/data/catch_sync_service.dart';
import 'package:fishergo/features/catches/data/catch_photo_storage.dart';
import 'package:fishergo/features/catches/domain/catch_log_entry.dart';

class _FakeRemote implements CatchRemoteDataSource {
  _FakeRemote({required this.failIds});

  final Set<String> failIds;
  final List<CatchLogEntry> uploaded = [];

  @override
  Future<void> uploadCatch({
    required String userId,
    required CatchLogEntry entry,
  }) async {
    if (failIds.contains(entry.id)) {
      throw Exception('fail');
    }
    uploaded.add(entry);
  }
}

class _FakePhotoUploader implements CatchPhotoUploader {
  final List<String> deleted = [];

  @override
  Future<String> upload({
    required String userId,
    required CatchLogEntry entry,
  }) async {
    return '$userId/${entry.id}.jpg';
  }

  @override
  Future<void> delete({required String objectPath}) async {
    deleted.add(objectPath);
  }
}

void main() {
  CatchLogEntry entry(String id) => CatchLogEntry(
        id: id,
        speciesId: 'sample-yellowfin-seabream',
        speciesName: '黃腳鱲',
        caughtAt: DateTime(2026, 5, 31, 9, 0),
      );

  test('returns skipped when supabase is not configured', () async {
    final service = CatchSyncService(
      remote: _FakeRemote(failIds: {}),
      isConfigured: () => false,
      currentUserId: () => 'user-1',
    );

    final result = await service.sync([entry('a'), entry('b')]);

    expect(result.skipped, 2);
    expect(result.synced, 0);
    expect(result.failed, 0);
  });

  test('returns skipped when user is not signed in', () async {
    final service = CatchSyncService(
      remote: _FakeRemote(failIds: {}),
      isConfigured: () => true,
      currentUserId: () => null,
    );

    final result = await service.sync([entry('a')]);

    expect(result.skipped, 1);
    expect(result.synced, 0);
    expect(result.failed, 0);
  });

  test('sync returns exact failed ids', () async {
    final service = CatchSyncService(
      remote: _FakeRemote(failIds: {'b'}),
      isConfigured: () => true,
      currentUserId: () => 'user-1',
    );

    final result = await service.sync([entry('a'), entry('b'), entry('c')]);

    expect(result.total, 3);
    expect(result.synced, 2);
    expect(result.failed, 1);
    expect(result.failedIds, {'b'});
  });

  test('sync carries real catch proof metadata to the remote', () async {
    final remote = _FakeRemote(failIds: {});
    final service = CatchSyncService(
      remote: remote,
      isConfigured: () => true,
      currentUserId: () => 'user-1',
    );
    final proofEntry = CatchLogEntry(
      id: 'proof-1',
      speciesId: 'fish-063',
      speciesName: '烏頭',
      caughtAt: DateTime.utc(2026, 6, 24, 8),
      photoPath: '/local/photo.jpg',
      isRealCatchProof: true,
      recognitionConfidence: 0.82,
      recognizedSpeciesId: 'fish-063',
      verifiedAt: DateTime.utc(2026, 6, 24, 8, 1),
    );

    final result = await service.sync([proofEntry]);

    expect(result.synced, 1);
    expect(remote.uploaded, hasLength(1));
    expect(remote.uploaded.single.isRealCatchProof, true);
    expect(remote.uploaded.single.recognitionConfidence, 0.82);
    expect(remote.uploaded.single.recognizedSpeciesId, 'fish-063');
    expect(remote.uploaded.single.verifiedAt, DateTime.utc(2026, 6, 24, 8, 1));
  });

  test('deletes the uploaded photo when the catch row insert fails', () async {
    final uploader = _FakePhotoUploader();
    final remote = SupabaseCatchRemoteDataSource(
      SupabaseClient('https://example.supabase.co', 'test-anon-key'),
      photoUploader: uploader,
      rowInserter: (_) async {
        throw StateError('row insert failed');
      },
    );

    await expectLater(
      remote.uploadCatch(
        userId: 'user-1',
        entry: CatchLogEntry(
          id: 'proof-cleanup',
          speciesId: 'fish-063',
          speciesName: '烏頭',
          caughtAt: DateTime.utc(2026, 6, 24, 8),
          photoPath: '/local/photo.jpg',
          isRealCatchProof: true,
        ),
      ),
      throwsStateError,
    );

    expect(uploader.deleted, ['user-1/proof-cleanup.jpg']);
  });
}
