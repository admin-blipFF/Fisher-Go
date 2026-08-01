import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:fishergo/features/catches/data/catch_photo_url_resolver.dart';

void main() {
  test('creates a short-lived signed URL for a private catch photo', () async {
    String? capturedBucket;
    String? capturedObjectPath;
    int? capturedExpiry;
    final resolver = SupabaseCatchPhotoUrlResolver(
      SupabaseClient('https://example.supabase.co', 'test-anon-key'),
      signedUrlCreator: ({
        required String bucket,
        required String objectPath,
        required int expiresInSeconds,
      }) async {
        capturedBucket = bucket;
        capturedObjectPath = objectPath;
        capturedExpiry = expiresInSeconds;
        return 'https://signed.example/$objectPath?token=test';
      },
    );

    final url = await resolver.resolve('user-123/catch-456.jpg');

    expect(url, 'https://signed.example/user-123/catch-456.jpg?token=test');
    expect(capturedBucket, 'catch-photos');
    expect(capturedObjectPath, 'user-123/catch-456.jpg');
    expect(capturedExpiry, 3600);
  });

  test('rejects object paths outside the user catch-photo namespace', () {
    final resolver = SupabaseCatchPhotoUrlResolver(
      SupabaseClient('https://example.supabase.co', 'test-anon-key'),
    );

    expect(
      () => resolver.resolve('other/path/escape.jpg'),
      throwsArgumentError,
    );
    expect(
      () => resolver.resolve('../catch-456.jpg'),
      throwsArgumentError,
    );
  });
}
