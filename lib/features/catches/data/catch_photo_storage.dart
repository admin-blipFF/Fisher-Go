import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/catch_log_entry.dart';

abstract class CatchPhotoUploader {
  Future<String> upload({
    required String userId,
    required CatchLogEntry entry,
  });
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
    if (!const {'jpg', 'png', 'webp'}.contains(extension)) {
      throw ArgumentError.value(
        objectPath,
        'objectPath',
        'Unsupported catch photo extension',
      );
    }
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

    final bytes = await XFile(sourcePath).readAsBytes();
    if (bytes.isEmpty) {
      throw StateError('Catch photo is empty');
    }

    final objectPath = storagePathFor(
      userId: userId,
      catchId: entry.id,
      photoPath: sourcePath,
    );
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
      'png' => 'png',
      'webp' => 'webp',
      _ => 'jpg',
    };
  }

  static void _assertSafeSegment(String value, String name) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed.contains('/') || trimmed.contains('..')) {
      throw ArgumentError.value(value, name, 'Unsafe storage path segment');
    }
  }
}
