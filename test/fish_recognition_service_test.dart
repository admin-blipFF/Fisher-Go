import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'package:fishergo/features/catches/data/fish_recognition_service.dart';

class _CaptureClient extends http.BaseClient {
  String? body;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request is http.Request) {
      body = request.body;
    }
    return http.StreamedResponse(
      Stream<List<int>>.fromIterable([
        utf8.encode(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content':
                      '{"species_id":"fish-001","confidence":0.9,"reasoning":"ok","alternatives":[]}'
                }
              }
            ]
          }),
        ),
      ]),
      200,
    );
  }
}

void main() {
  test(
      'recognition prompt sends the curated species list instead of Dart objects',
      () async {
    final client = _CaptureClient();
    final service = FishRecognitionService(apiKey: 'test-key', client: client);
    final image = XFile.fromData(Uint8List.fromList([1, 2, 3]));

    await service.recognize(image);

    final payload = jsonDecode(client.body!) as Map<String, dynamic>;
    final messages = payload['messages'] as List<dynamic>;
    final system = messages.first as Map<String, dynamic>;
    final content = system['content'] as String;

    expect(content, contains('fish-001:'));
    expect(content, isNot(contains('Instance of')));
  });
}
