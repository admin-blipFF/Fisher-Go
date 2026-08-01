import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:fishergo/features/fishing_spots/data/fishing_spot_repository.dart';

class _UnavailableClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream<List<int>>.value(const <int>[]),
      HttpStatus.serviceUnavailable,
      request: request,
    );
  }
}

void main() {
  test('public map query requires public-accessible verified rows', () {
    final source = File(
      'lib/features/fishing_spots/data/fishing_spot_repository.dart',
    ).readAsStringSync();

    expect(source, contains(".eq('public_access', true)"));
    expect(source, contains('spot.isActiveVerified && spot.publicAccess'));
  });

  test('configured remote registry failure does not resurrect bundled spots',
      () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-anon-key',
      httpClient: _UnavailableClient(),
    );

    final spots = await FishingSpotRepository(
      client: client,
      remoteRegistryEnabled: true,
    ).getActiveVerifiedSpots();

    expect(spots, isEmpty);
  });
}
