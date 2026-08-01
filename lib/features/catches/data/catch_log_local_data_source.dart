import 'package:hive/hive.dart';

import '../../../core/auth/local_account_service.dart';
import '../domain/catch_log_entry.dart';

class CatchLogLocalDataSource {
  CatchLogLocalDataSource({
    String? boxName,
    this.itemsKey = 'items',
  }) : _explicitBoxName = boxName;

  final String? _explicitBoxName;
  final String itemsKey;
  List<CatchLogEntry> _fallbackMemory = [];

  String get boxName =>
      _explicitBoxName ?? LocalAccountService.catchQueueBoxName;

  Future<List<CatchLogEntry>> loadPending() async {
    try {
      final box = await _openBoxOrNull();
      if (box == null) return List.unmodifiable(_fallbackMemory);

      final raw = box.get(itemsKey);
      if (raw is! List) return const [];

      return raw
          .whereType<Map>()
          .map((item) => CatchLogEntry.fromMap(item))
          .toList(growable: false);
    } catch (_) {
      return List.unmodifiable(_fallbackMemory);
    }
  }

  Future<void> savePending(List<CatchLogEntry> entries) async {
    final box = await _openBoxOrNull();
    if (box == null) {
      _fallbackMemory = List.of(entries);
      return;
    }

    final payload =
        entries.map((entry) => entry.toMap()).toList(growable: false);
    await box.put(itemsKey, payload);
  }

  Future<void> addPending(CatchLogEntry entry) async {
    final current = await loadPending();
    await savePending([entry, ...current]);
  }

  Future<void> clearPending() async {
    final box = await _openBoxOrNull();
    if (box == null) {
      _fallbackMemory = [];
      return;
    }

    await box.put(itemsKey, const <Map<String, dynamic>>[]);
  }

  Future<Box<dynamic>?> _openBoxOrNull() async {
    try {
      if (Hive.isBoxOpen(boxName)) return Hive.box<dynamic>(boxName);
      return await Hive.openBox<dynamic>(boxName);
    } catch (_) {
      return null;
    }
  }
}
