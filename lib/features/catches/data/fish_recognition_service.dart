import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_picker/image_picker.dart';
import '../../fish/domain/fish_species.dart';
import '../../fish/data/sample_fish_species_data_source.dart';

/// AI fish recognition service using VectorEngine (qvq-max visual reasoning model).
class FishRecognitionService {
  static const String _baseUrl =
      'https://api.vectorengine.ai/v1/chat/completions';
  static const String _model = 'qvq-max';

  final String _apiKey;
  final http.Client _client;

  FishRecognitionService({String? apiKey, http.Client? client})
      : _apiKey = apiKey ?? dotenv.env['VECTOR_ENGINE_API_KEY'] ?? '',
        _client = client ?? http.Client();

  Future<FishRecognitionResult> recognize(XFile imageFile) async {
    if (_apiKey.isEmpty) {
      return FishRecognitionResult.error('VectorEngine API key not configured');
    }

    final imageBytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(imageBytes);

    // Load all species for the prompt
    final allSpecies = const SampleFishSpeciesDataSource().loadSpecies();

    // Build Chinese species list
    final speciesList = allSpecies.map((s) {
      final localName =
          s.localNameZh?.isNotEmpty == true ? s.localNameZh! : s.commonNameZh;
      final scientificName =
          s.scientificName != null ? ' (${s.scientificName})' : '';
      return '${s.id}: $localName$scientificName';
    }).join('\n');

    final systemPrompt = '''
你是一個香港魚類辨識專家。根據用戶上傳的魚類照片，辨識魚種。

## 可選魚種列表：
$speciesList

## 輸出要求：
1. 只從以上列表中選擇最匹配的魚種
2. 如果無法確認，選擇最接近的一種並說明「未能完全確認」
3. 返回以下 JSON 格式（只返回 JSON，不要有其他文字）：
{
  "species_id": "fish-xxx",
  "confidence": 0.95,
  "reasoning": "簡短推理過程",
  "alternatives": [{"species_id": "fish-yyy", "confidence": 0.3, "reason": "理由"}]
}
''';

    final userMessage = '請辨識這張魚類照片。';

    try {
      final response = await _client
          .post(
            Uri.parse(_baseUrl),
            headers: {
              'Authorization': 'Bearer $_apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': _model,
              'messages': [
                {'role': 'system', 'content': systemPrompt},
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': userMessage},
                    {
                      'type': 'image_url',
                      'image_url': {
                        'url': 'data:image/jpeg;base64,$base64Image'
                      }
                    }
                  ],
                },
              ],
              'max_tokens': 1024,
              'temperature': 0.3,
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode != 200) {
        return FishRecognitionResult.error(
            'API error: ${response.statusCode} - ${response.body}');
      }

      final data = jsonDecode(response.body);
      final content = data['choices'][0]['message']['content'] as String;

      // Parse JSON from response
      final jsonStart = content.indexOf('{');
      final jsonEnd = content.lastIndexOf('}');
      if (jsonStart == -1 || jsonEnd == -1) {
        return FishRecognitionResult.error('Invalid response format');
      }

      final jsonStr = content.substring(jsonStart, jsonEnd + 1);
      final result = jsonDecode(jsonStr);

      final speciesId = result['species_id'] as String;
      final confidence = (result['confidence'] as num).toDouble();
      final reasoning = result['reasoning'] as String;
      final alternatives = (result['alternatives'] as List?)
              ?.map((a) => AlternativeFish(
                    speciesId: a['species_id'] as String,
                    confidence: (a['confidence'] as num).toDouble(),
                    reason: a['reason'] as String? ?? '',
                  ))
              .toList() ??
          [];

      // Find the FishSpecies object
      final matchedSpecies = allSpecies.firstWhere(
        (s) => s.id == speciesId,
        orElse: () => allSpecies.first,
      );

      return FishRecognitionResult.success(
        species: matchedSpecies,
        confidence: confidence,
        reasoning: reasoning,
        alternatives: alternatives,
        allSpecies: allSpecies,
      );
    } catch (e) {
      return FishRecognitionResult.error('辨識失敗：$e');
    }
  }
}

/// Result of fish recognition.
class FishRecognitionResult {
  final bool isSuccess;
  final FishSpecies? species;
  final double? confidence;
  final String? reasoning;
  final String? errorMessage;
  final List<AlternativeFish> alternatives;
  final List<FishSpecies> allSpecies;

  const FishRecognitionResult._({
    required this.isSuccess,
    this.species,
    this.confidence,
    this.reasoning,
    this.errorMessage,
    this.alternatives = const [],
    this.allSpecies = const [],
  });

  factory FishRecognitionResult.success({
    required FishSpecies species,
    required double confidence,
    required String reasoning,
    required List<AlternativeFish> alternatives,
    required List<FishSpecies> allSpecies,
  }) {
    return FishRecognitionResult._(
      isSuccess: true,
      species: species,
      confidence: confidence,
      reasoning: reasoning,
      alternatives: alternatives,
      allSpecies: allSpecies,
    );
  }

  factory FishRecognitionResult.error(String message) {
    return FishRecognitionResult._(
      isSuccess: false,
      errorMessage: message,
    );
  }
}

/// Alternative fish species suggestion.
class AlternativeFish {
  final String speciesId;
  final double confidence;
  final String reason;

  const AlternativeFish({
    required this.speciesId,
    required this.confidence,
    required this.reason,
  });
}
