import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/catch_log_entry.dart';

abstract class CatchPhotoUploader {
  Future<String> upload({
    required String userId,
    required CatchLogEntry entry,
  });

  /// Removes an object created by a failed catch-row transaction.
  ///
  /// Implementations that do not own remote storage can keep the default
  /// no-op; the Supabase implementation overrides it.
  Future<void> delete({required String objectPath}) async {}
}

typedef CatchPhotoBinaryUploader = Future<void> Function({
  required String bucket,
  required String objectPath,
  required Uint8List bytes,
  required String contentType,
});

/// Authenticated catch-photo storage contract shared by Android and Web.
class CatchPhotoStorage implements CatchPhotoUploader {
  CatchPhotoStorage(
    this._client, {
    this.bucket = 'catch-photos',
    CatchPhotoBinaryUploader? binaryUploader,
  }) : _binaryUploader = binaryUploader;

  final SupabaseClient _client;
  final String bucket;
  final CatchPhotoBinaryUploader? _binaryUploader;

  static String storagePathFor({
    required String userId,
    required String catchId,
    required String photoPath,
  }) {
    _assertSafeSegment(userId, 'userId');
    _assertSafeSegment(catchId, 'catchId');
    if (photoPath.trim().isEmpty) {
      throw ArgumentError.value(photoPath, 'photoPath', 'Photo is required');
    }
    final extension = _extensionFor(photoPath);
    return '$userId/$catchId.$extension';
  }

  static String contentTypeFor(String photoPath) {
    return switch (_extensionFor(photoPath)) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'heic' => 'image/heic',
      'heif' => 'image/heif',
      _ => 'image/jpeg',
    };
  }

  static void assertSafeObjectPath(String objectPath) {
    final segments = objectPath.split('/');
    if (segments.length != 2) {
      throw ArgumentError.value(
        objectPath,
        'objectPath',
        'Catch photo paths must be namespaced by one user folder',
      );
    }
    _assertSafeSegment(segments[0], 'objectPath');
    _assertSafeSegment(segments[1].split('.').first, 'objectPath');
    final extension = _extensionFor(segments[1]);
    if (!const {'jpg', 'png', 'webp', 'heic', 'heif'}.contains(extension)) {
      throw ArgumentError.value(
        objectPath,
        'objectPath',
        'Unsupported catch photo extension',
      );
    }
  }

  @override
  Future<void> delete({required String objectPath}) async {
    assertSafeObjectPath(objectPath);
    await _client.storage.from(bucket).remove([objectPath]);
  }

  @override
  Future<String> upload({
    required String userId,
    required CatchLogEntry entry,
  }) async {
    final sourcePath = entry.photoPath?.trim();
    if (sourcePath == null || sourcePath.isEmpty) {
      throw ArgumentError.value(
          entry.photoPath, 'photoPath', 'Photo is required');
    }

    // Reject non-image paths before touching the local file system or remote
    // storage. This keeps video uploads out of the private catch-photo bucket.
    final objectPath = storagePathFor(
      userId: userId,
      catchId: entry.id,
      photoPath: sourcePath,
    );
    final bytes = await XFile(sourcePath).readAsBytes();
    if (bytes.isEmpty) {
      throw StateError('Catch photo is empty');
    }

    final contentType = contentTypeFor(sourcePath);
    final binaryUploader = _binaryUploader;
    if (binaryUploader != null) {
      await binaryUploader(
        bucket: bucket,
        objectPath: objectPath,
        bytes: bytes,
        contentType: contentType,
      );
    } else {
      await _client.storage.from(bucket).uploadBinary(
            objectPath,
            bytes,
            fileOptions: FileOptions(
              contentType: contentType,
              upsert: true,
            ),
          );
    }
    return objectPath;
  }

  static String _extensionFor(String photoPath) {
    final withoutQuery = photoPath.split('?').first;
    final fileName = withoutQuery.split('/').last.toLowerCase();
    final dot = fileName.lastIndexOf('.');
    final extension = dot == -1 ? '' : fileName.substring(dot + 1);
    return switch (extension) {
      '' => 'jpg',
      'jpg' || 'jpeg' => 'jpg',
      'png' => 'png',
      'webp' => 'webp',
      'heic' => 'heic',
      'heif' => 'heif',
      _ => throw ArgumentError.value(
          photoPath,
          'photoPath',
          'Only still-image files are supported',
        ),
    };
  }

  static void _assertSafeSegment(String value, String name) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed.contains('/') || trimmed.contains('..')) {
      throw ArgumentError.value(value, name, 'Unsafe storage path segment');
    }
  }
}
