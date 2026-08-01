/// Validates the compact content format used by the admin fishing-spot editor.
class FishingSpotContentDraft {
  const FishingSpotContentDraft({
    required this.habitatTags,
    required this.speciesWeights,
  });

  final List<String> habitatTags;
  final Map<String, double> speciesWeights;

  factory FishingSpotContentDraft.fromText({
    required String habitatTags,
    required String speciesWeights,
  }) {
    return FishingSpotContentDraft(
      habitatTags: parseHabitatTags(habitatTags),
      speciesWeights: parseSpeciesWeights(speciesWeights),
    );
  }

  static List<String> parseHabitatTags(String input) {
    final tags = <String>[];
    for (final raw in input.replaceAll('\n', ',').split(',')) {
      final tag = raw.trim().toLowerCase();
      if (tag.isEmpty) continue;
      if (!RegExp(r'^[a-z0-9][a-z0-9-]*$').hasMatch(tag)) {
        throw FormatException('棲地標籤格式不正確：$tag');
      }
      if (!tags.contains(tag)) tags.add(tag);
    }
    if (tags.length > 12) {
      throw const FormatException('棲地標籤最多 12 個');
    }
    return List.unmodifiable(tags);
  }

  static Map<String, double> parseSpeciesWeights(String input) {
    final weights = <String, double>{};
    final linePattern = RegExp(
      r'^\s*(fish-\d+)\s*[=:]\s*([0-9]+(?:\.[0-9]+)?)\s*$',
    );
    for (final rawLine in input.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      final match = linePattern.firstMatch(line);
      if (match == null) {
        throw FormatException('魚種權重格式不正確：$line');
      }
      final id = match.group(1)!;
      final value = double.parse(match.group(2)!);
      if (value <= 0 || value > 100) {
        throw FormatException('魚種權重須介乎 0 至 100：$id');
      }
      if (weights.containsKey(id)) {
        throw FormatException('魚種不可重複：$id');
      }
      weights[id] = value;
    }
    return Map.unmodifiable(weights);
  }

  static List<String> normalizeHabitatTags(Iterable<String> values) {
    return parseHabitatTags(values.join(','));
  }

  static Map<String, double> normalizeSpeciesWeights(
    Map<String, num> values,
  ) {
    final lines = values.entries.map((entry) {
      final value = entry.value.toDouble();
      return '${entry.key} = $value';
    }).join('\n');
    return parseSpeciesWeights(lines);
  }

  static String formatSpeciesWeights(Map<String, num> values) {
    final normalized = normalizeSpeciesWeights(values);
    final keys = normalized.keys.toList()..sort();
    return keys
        .map((key) => '$key = ${_formatNumber(normalized[key]!)}')
        .join('\n');
  }

  static String _formatNumber(double value) {
    return value == value.truncateToDouble()
        ? value.toInt().toString()
        : value.toString();
  }
}
