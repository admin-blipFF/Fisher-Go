import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:fishergo/features/catches/data/catch_photo_storage.dart';
import 'package:fishergo/features/catches/domain/catch_log_entry.dart';

void main() {
  test('storage path is namespaced by user and catch id', () {
    expect(
      CatchPhotoStorage.storagePathFor(
        userId: 'user-123',
        catchId: 'catch-456',
        photoPath: '/tmp/catch-456.webp',
      ),
      'user-123/catch-456.webp',
    );
  });

  test('content type follows supported image extensions', () {
    expect(CatchPhotoStorage.contentTypeFor('fish.JPG'), 'image/jpeg');
    expect(CatchPhotoStorage.contentTypeFor('fish.png'), 'image/png');
    expect(CatchPhotoStorage.contentTypeFor('fish.webp'), 'image/webp');
    expect(CatchPhotoStorage.contentTypeFor('fish.unknown'), 'image/jpeg');
  });

  test('storage path rejects empty or path-injecting account ids', () {
    expect(
      () => CatchPhotoStorage.storagePathFor(
        userId: '',
        catchId: 'catch-456',
        photoPath: 'fish.jpg',
      ),
      throwsArgumentError,
    );
    expect(
      () => CatchPhotoStorage.storagePathFor(
        userId: 'user/other',
        catchId: 'catch-456',
        photoPath: 'fish.jpg',
      ),
      throwsArgumentError,
    );
  });

  test('upload reads the local image and forwards it to the storage boundary',
      () async {
    final directory = await Directory.systemTemp.createTemp('fishergo_photo_');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/catch.png');
    final bytes = Uint8List.fromList([137, 80, 78, 71]);
    await file.writeAsBytes(bytes);

    String? capturedBucket;
    String? capturedObjectPath;
    Uint8List? uploadedBytes;
    String? capturedContentType;
    final storage = CatchPhotoStorage(
      SupabaseClient('https://example.supabase.co', 'test-anon-key'),
      binaryUploader: ({
        required String bucket,
        required String objectPath,
        required Uint8List bytes,
        required String contentType,
      }) async {
        capturedBucket = bucket;
        capturedObjectPath = objectPath;
        uploadedBytes = bytes;
        capturedContentType = contentType;
      },
    );

    final object = await storage.upload(
      userId: 'user-123',
      entry: CatchLogEntry(
        id: 'catch-456',
        speciesId: 'fish-010',
        speciesName: '白䱛',
        caughtAt: DateTime(2026, 7, 19),
        photoPath: file.path,
        isRealCatchProof: true,
      ),
    );

    expect(object, 'user-123/catch-456.png');
    expect(capturedBucket, 'catch-photos');
    expect(capturedObjectPath, object);
    expect(uploadedBytes, bytes);
    expect(capturedContentType, 'image/png');
  });
}
