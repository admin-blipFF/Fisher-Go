import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:fishergo/features/catches/data/catch_history_service.dart';
import 'package:fishergo/features/catches/data/catch_photo_url_resolver.dart';

class _FakeDataSource implements CatchHistoryDataSource {
  _FakeDataSource(this.records);

  final List<RemoteCatchRecord> records;

  @override
  Future<List<RemoteCatchRecord>> fetchOwnCatches({
    required String userId,
  }) async {
    return records;
  }
}

class _FakeResolver implements CatchPhotoUrlResolver {
  _FakeResolver(this.urls);

  final Map<String, String> urls;

  @override
  Future<String> resolve(
    String objectPath, {
    int expiresInSeconds = 3600,
  }) async {
    return urls[objectPath] ?? (throw StateError('missing signed URL'));
  }
}

void main() {
  test('Supabase history data source maps the own-catch query rows', () async {
    String? queriedUserId;
    final source = SupabaseCatchHistoryDataSource(
      SupabaseClient('https://example.supabase.co', 'test-anon-key'),
      query: (userId) async {
        queriedUserId = userId;
        return [
          {
            'id': 'catch-3',
            'species_name': '白䱛',
            'caught_at': '2026-07-17T10:00:00Z',
            'photo_storage_path': 'user-3/catch-3.webp',
            'is_real_catch_proof': true,
            'moderation_status': 'pending',
          },
        ];
      },
    );

    final records = await source.fetchOwnCatches(userId: 'user-3');

    expect(queriedUserId, 'user-3');
    expect(records.single.id, 'catch-3');
    expect(records.single.photoStoragePath, 'user-3/catch-3.webp');
    expect(records.single.isRealCatchProof, isTrue);
    expect(records.single.moderationStatus, 'pending');
  });

  test('hydrates private photo paths into signed URLs for own catch history',
      () async {
    final service = CatchHistoryService(
      dataSource: _FakeDataSource([
        RemoteCatchRecord(
          id: 'catch-1',
          speciesName: '烏頭',
          caughtAt: DateTime.utc(2026, 7, 19, 8),
          photoStoragePath: 'user-1/catch-1.jpg',
          isRealCatchProof: true,
        ),
      ]),
      photoUrlResolver: _FakeResolver({
        'user-1/catch-1.jpg': 'https://signed.example/catch-1.jpg',
      }),
    );

    final items = await service.load(userId: 'user-1');

    expect(items, hasLength(1));
    expect(items.single.record.speciesName, '烏頭');
    expect(items.single.photoUrl, 'https://signed.example/catch-1.jpg');
    expect(items.single.record.isRealCatchProof, isTrue);
  });

  test('keeps history visible when one private photo cannot be resolved',
      () async {
    final service = CatchHistoryService(
      dataSource: _FakeDataSource([
        RemoteCatchRecord(
          id: 'catch-2',
          speciesName: '黃腳鱲',
          caughtAt: DateTime.utc(2026, 7, 18),
          photoStoragePath: 'user-1/catch-2.jpg',
        ),
      ]),
      photoUrlResolver: _FakeResolver(const {}),
    );

    final items = await service.load(userId: 'user-1');

    expect(items, hasLength(1));
    expect(items.single.record.id, 'catch-2');
    expect(items.single.photoUrl, isNull);
  });
}
