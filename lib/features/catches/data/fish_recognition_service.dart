import 'dart:convert';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/public_app_config.dart';
import '../../../core/config/supabase_config.dart';
import '../../fish/data/sample_fish_species_data_source.dart';
import '../../fish/domain/fish_species.dart';

typedef FishRecognitionInvoker = Future<dynamic> Function(
  Map<String, dynamic> body,
);

/// AI fish recognition service through the authenticated Supabase function.
class FishRecognitionService {
  final FishRecognitionInvoker? _invoke;
  final SupabaseClient? _supabaseClient;

  FishRecognitionService({
    FishRecognitionInvoker? invoke,
    SupabaseClient? client,
  })  : _invoke = invoke,
        _supabaseClient = client;

  Future<FishRecognitionResult> recognize(XFile imageFile) async {
    if (!PublicAppConfig.fishRecognitionEnabled) {
      return FishRecognitionResult.error('魚類辨識服務暫時關閉');
    }
    if (_invoke == null && !SupabaseConfig.isConfigured) {
      return FishRecognitionResult.error('魚類辨識服務尚未設定');
    }

    final imageBytes = await imageFile.readAsBytes();
    if (imageBytes.length > 8 * 1024 * 1024) {
      return FishRecognitionResult.error('相片太大，請選擇少於 8 MB 的相片');
    }
    final base64Image = base64Encode(imageBytes);
    final allSpecies = const SampleFishSpeciesDataSource().loadSpecies();

    final speciesCatalog = allSpecies
        .map(
          (s) => <String, dynamic>{
            'id': s.id,
            'name': s.displayLocalName,
            if (s.scientificName?.trim().isNotEmpty == true)
              'scientific_name': s.scientificName,
          },
        )
        .toList(growable: false);

    try {
      final response = await (_invoke ?? _invokeWithSupabase)(
        {
          'image_base64': base64Image,
          'species_catalog': speciesCatalog,
        },
      );
      final result = _extractResult(_asMap(response));
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

      FishSpecies? matchedSpecies;
      for (final species in allSpecies) {
        if (species.id == speciesId) {
          matchedSpecies = species;
          break;
        }
      }
      if (matchedSpecies == null) {
        return FishRecognitionResult.error('辨識結果不在已授權魚種列表內');
      }

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

  Future<dynamic> _invokeWithSupabase(Map<String, dynamic> body) async {
    final client = _supabaseClient ?? Supabase.instance.client;
    final response = await client.functions.invoke(
      PublicAppConfig.fishRecognitionFunction,
      body: body,
    );
    if (response.status < 200 || response.status >= 300) {
      throw StateError('辨識服務錯誤（${response.status}）');
    }
    return response.data;
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const FormatException('辨識服務回傳格式錯誤');
  }

  static Map<String, dynamic> _extractResult(Map<String, dynamic> data) {
    if (data.containsKey('species_id')) return data;
    final choices = data['choices'];
    if (choices is! List || choices.isEmpty) {
      throw const FormatException('辨識服務沒有回傳魚種');
    }
    final message = _asMap(_asMap(choices.first)['message']);
    final content = message['content'];
    if (content is! String) {
      throw const FormatException('辨識服務回傳內容錯誤');
    }
    final jsonStart = content.indexOf('{');
    final jsonEnd = content.lastIndexOf('}');
    if (jsonStart == -1 || jsonEnd <= jsonStart) {
      throw const FormatException('辨識服務回傳內容不是 JSON');
    }
    return _asMap(jsonDecode(content.substring(jsonStart, jsonEnd + 1)));
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
