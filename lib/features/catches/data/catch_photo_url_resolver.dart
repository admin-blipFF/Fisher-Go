import 'package:supabase_flutter/supabase_flutter.dart';

import 'catch_photo_storage.dart';

abstract class CatchPhotoUrlResolver {
  Future<String> resolve(
    String objectPath, {
    int expiresInSeconds = 3600,
  });
}

typedef CatchPhotoSignedUrlCreator = Future<String> Function({
  required String bucket,
  required String objectPath,
  required int expiresInSeconds,
});

/// Resolves private catch-photo object paths only when the image is needed.
class SupabaseCatchPhotoUrlResolver implements CatchPhotoUrlResolver {
  SupabaseCatchPhotoUrlResolver(
    this._client, {
    this.bucket = 'catch-photos',
    CatchPhotoSignedUrlCreator? signedUrlCreator,
  }) : _signedUrlCreator = signedUrlCreator;

  final SupabaseClient _client;
  final String bucket;
  final CatchPhotoSignedUrlCreator? _signedUrlCreator;

  @override
  Future<String> resolve(
    String objectPath, {
    int expiresInSeconds = 3600,
  }) {
    CatchPhotoStorage.assertSafeObjectPath(objectPath);
    if (expiresInSeconds <= 0) {
      throw ArgumentError.value(
        expiresInSeconds,
        'expiresInSeconds',
        'Signed URL expiry must be positive',
      );
    }

    final signedUrlCreator = _signedUrlCreator;
    if (signedUrlCreator != null) {
      return signedUrlCreator(
        bucket: bucket,
        objectPath: objectPath,
        expiresInSeconds: expiresInSeconds,
      );
    }
    return _client.storage.from(bucket).createSignedUrl(
          objectPath,
          expiresInSeconds,
        );
  }
}
