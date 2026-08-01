import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'package:fishergo/features/catches/data/fish_recognition_service.dart';

void main() {
  test('recognition sends catalog hints without a client-controlled prompt',
      () async {
    Map<String, dynamic>? request;
    final service = FishRecognitionService(
      invoke: (body) async {
        request = body;
        return {
          'species_id': 'fish-001',
          'confidence': 0.9,
          'reasoning': 'ok',
          'alternatives': <dynamic>[],
        };
      },
    );
    final image = XFile.fromData(Uint8List.fromList([1, 2, 3]));

    final result = await service.recognize(image);

    expect(result.isSuccess, isTrue);
    expect(request?['image_base64'], isNotEmpty);
    expect(request?['system_prompt'], isNull);
    expect(request?['species_catalog'], isA<List<dynamic>>());
    expect(
      (request?['species_catalog'] as List).first['id'],
      'fish-001',
    );
  });

  test('recognition rejects an unknown species instead of defaulting to fish 1',
      () async {
    final service = FishRecognitionService(
      invoke: (_) async => {
        'species_id': 'fish-not-authorized',
        'confidence': 0.9,
        'reasoning': 'bad',
        'alternatives': <dynamic>[],
      },
    );

    final result = await service.recognize(
      XFile.fromData(Uint8List.fromList([1, 2, 3])),
    );

    expect(result.isSuccess, isFalse);
    expect(result.errorMessage, contains('已授權魚種'));
  });
}
