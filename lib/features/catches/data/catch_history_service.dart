import 'package:supabase_flutter/supabase_flutter.dart';

import 'catch_photo_url_resolver.dart';

class RemoteCatchRecord {
  const RemoteCatchRecord({
    required this.id,
    required this.speciesName,
    required this.caughtAt,
    this.photoStoragePath,
    this.isRealCatchProof = false,
    this.moderationStatus = 'approved',
  });

  final String id;
  final String speciesName;
  final DateTime caughtAt;
  final String? photoStoragePath;
  final bool isRealCatchProof;
  final String moderationStatus;

  factory RemoteCatchRecord.fromMap(Map<String, dynamic> map) {
    final rawCaughtAt = map['caught_at'];
    final caughtAt = rawCaughtAt is String
        ? DateTime.tryParse(rawCaughtAt)
        : rawCaughtAt is DateTime
            ? rawCaughtAt
            : null;
    if (caughtAt == null) {
      throw FormatException('Remote catch is missing caught_at');
    }

    final rawPhotoPath = (map['photo_storage_path'] as String?)?.trim();
    return RemoteCatchRecord(
      id: (map['id'] as String?)?.trim() ?? '',
      speciesName: (map['species_name'] as String?)?.trim() ?? '未知魚種',
      caughtAt: caughtAt,
      photoStoragePath:
          rawPhotoPath == null || rawPhotoPath.isEmpty ? null : rawPhotoPath,
      isRealCatchProof: map['is_real_catch_proof'] == true,
      moderationStatus:
          (map['moderation_status'] as String?)?.trim().isNotEmpty == true
              ? (map['moderation_status'] as String).trim()
              : 'approved',
    );
  }
}

abstract class CatchHistoryDataSource {
  Future<List<RemoteCatchRecord>> fetchOwnCatches({
    required String userId,
  });
}

typedef CatchHistoryQuery = Future<List<Map<String, dynamic>>> Function(
  String userId,
);

class SupabaseCatchHistoryDataSource implements CatchHistoryDataSource {
  SupabaseCatchHistoryDataSource(
    this._client, {
    CatchHistoryQuery? query,
  }) : _query = query;

  final SupabaseClient _client;
  final CatchHistoryQuery? _query;

  @override
  Future<List<RemoteCatchRecord>> fetchOwnCatches({
    required String userId,
  }) async {
    final query = _query;
    final rows =
        query == null ? await _fetchFromSupabase(userId) : await query(userId);
    return rows.map(RemoteCatchRecord.fromMap).toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> _fetchFromSupabase(String userId) async {
    final raw = await _client
        .from('catches')
        .select(
          'id,species_name,caught_at,photo_storage_path,is_real_catch_proof,'
          'moderation_status',
        )
        .eq('user_id', userId)
        .order('caught_at', ascending: false)
        .limit(50);
    return List<Map<String, dynamic>>.from(raw);
  }
}

class CatchHistoryItem {
  const CatchHistoryItem({
    required this.record,
    this.photoUrl,
  });

  final RemoteCatchRecord record;
  final String? photoUrl;
}

class CatchHistoryService {
  CatchHistoryService({
    required CatchHistoryDataSource dataSource,
    CatchPhotoUrlResolver? photoUrlResolver,
  })  : _dataSource = dataSource,
        _photoUrlResolver = photoUrlResolver;

  final CatchHistoryDataSource _dataSource;
  final CatchPhotoUrlResolver? _photoUrlResolver;

  Future<List<CatchHistoryItem>> load({required String userId}) async {
    final records = await _dataSource.fetchOwnCatches(userId: userId);
    return Future.wait(
      records.map((record) async {
        final photoPath = record.photoStoragePath;
        final resolver = _photoUrlResolver;
        if (photoPath == null || resolver == null) {
          return CatchHistoryItem(record: record);
        }

        String? photoUrl;
        try {
          photoUrl = await resolver.resolve(photoPath);
        } catch (_) {
          // A single expired/deleted object must not hide the catch record.
        }
        return CatchHistoryItem(record: record, photoUrl: photoUrl);
      }),
    );
  }
}
