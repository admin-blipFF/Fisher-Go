import 'package:hive/hive.dart';

import '../../../core/auth/local_account_service.dart';
import '../data/player_profile_sync_service.dart';
import '../domain/game_shop_item.dart';

class ProfileWalletService {
  static String get _profileBoxName => LocalAccountService.profileBoxName;
  static const _defaultCoins = 500;

  /// Cloud-first coin balance. Reads Supabase first, falls back to Hive cache.
  static Future<int> getCoins() async {
    final userId = LocalAccountService.supabaseUserId;
    if (userId != null) {
      try {
        final profile = await PlayerProfileSyncService.load(userId);
        await _cacheCoins(profile.coins);
        return profile.coins;
      } catch (_) {}
    }
    final state = await _loadState();
    return (state['coins'] as num?)?.toInt() ?? _defaultCoins;
  }

  static Future<void> _cacheCoins(int coins) async {
    try {
      final box = await Hive.openBox(_profileBoxName);
      final state = await _loadState();
      state['coins'] = coins;
      await box.put('avatar_state', state);
    } catch (_) {}
  }

  /// Cloud-first addCoins. Writes to Supabase + Hive cache.
  static Future<int> addCoins(int amount, {required String reason}) async {
    final userId = LocalAccountService.supabaseUserId;
    int updated;
    if (userId != null) {
      try {
        updated = await PlayerProfileSyncService.addCoins(userId, amount);
        if (updated >= 0) {
          final box = await Hive.openBox(_profileBoxName);
          final state = await _loadState();
          state['coins'] = updated;
          _appendHistory(state, amount: amount, reason: reason, type: 'income');
          await box.put('avatar_state', state);
          return updated;
        }
        return -1;
      } catch (_) {
        return -1;
      }
    }
    // Fallback to Hive-only
    final box = await Hive.openBox(_profileBoxName);
    final state = await _loadState();
    final current = (state['coins'] as num?)?.toInt() ?? _defaultCoins;
    updated = current + amount;
    state['coins'] = updated;
    _appendHistory(state, amount: amount, reason: reason, type: 'income');
    await box.put('avatar_state', state);
    return updated;
  }

  /// Cloud-first spendCoins. Returns updated balance, or -1 if insufficient.
  static Future<int> spendCoins(int amount, {required String reason}) async {
    final userId = LocalAccountService.supabaseUserId;
    int updated;
    if (userId != null) {
      try {
        updated = await PlayerProfileSyncService.deductCoins(userId, amount);
        if (updated >= 0) {
          await _cacheCoins(updated);
          return updated;
        }
        return -1;
      } catch (_) {}
    }
    // Fallback to Hive-only
    final box = await Hive.openBox(_profileBoxName);
    final state = await _loadState();
    final current = (state['coins'] as num?)?.toInt() ?? _defaultCoins;
    if (current < amount) return -1;
    updated = current - amount;
    state['coins'] = updated;
    _appendHistory(state, amount: -amount, reason: reason, type: 'expense');
    await box.put('avatar_state', state);
    return updated;
  }

  static Future<List<Map<String, dynamic>>> getCoinHistory() async {
    final state = await _loadState();
    final raw = (state['coinHistory'] as List?) ?? const [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
  }

  static Future<Map<String, int>> getConsumables() async {
    final state = await _loadState();
    _ensureDefaults(state);
    return Map<String, int>.from(state['consumables'] as Map);
  }

  static Future<Map<String, String>> getEquippedItems() async {
    final state = await _loadState();
    _ensureDefaults(state);
    return Map<String, String>.from(state['equipped'] as Map);
  }

  static Future<int> getConsumableQuantity(String itemId) async {
    final consumables = await getConsumables();
    return consumables[itemId] ?? 0;
  }

  static Future<int> addConsumable(
    String itemId,
    int quantity, {
    required String reason,
  }) async {
    final box = await Hive.openBox(_profileBoxName);
    final state = await _loadState();
    _ensureDefaults(state);

    final consumables = Map<String, int>.from(state['consumables'] as Map);
    final updated = (consumables[itemId] ?? 0) + quantity;
    consumables[itemId] = updated;
    state['consumables'] = consumables;
    _appendHistory(
      state,
      amount: 0,
      reason: '$reason +$quantity',
      type: 'item',
    );

    await box.put('avatar_state', state);
    return updated;
  }

  static Future<bool> consumeConsumable(
    String itemId, {
    int quantity = 1,
    required String reason,
  }) async {
    final box = await Hive.openBox(_profileBoxName);
    final state = await _loadState();
    _ensureDefaults(state);

    final consumables = Map<String, int>.from(state['consumables'] as Map);
    final current = consumables[itemId] ?? 0;
    if (current < quantity) return false;

    consumables[itemId] = current - quantity;
    state['consumables'] = consumables;
    _appendHistory(
      state,
      amount: 0,
      reason: '$reason -$quantity',
      type: 'item',
    );

    await box.put('avatar_state', state);
    return true;
  }

  /// Cloud-first purchase. Deducts coins from Supabase first, falls back to Hive.
  static Future<bool> buyConsumable(GameShopItem item) async {
    // Check coins via cloud-first
    final coins = await getCoins();
    if (coins < item.price) return false;

    // Deduct via cloud
    final userId = LocalAccountService.supabaseUserId;
    if (userId != null) {
      final result =
          await PlayerProfileSyncService.deductCoins(userId, item.price);
      if (result < 0) return false;
    } else {
      // No cloud — deduct from Hive directly
      final box = await Hive.openBox(_profileBoxName);
      final state = await _loadState();
      final current = (state['coins'] as num?)?.toInt() ?? _defaultCoins;
      if (current < item.price) return false;
      state['coins'] = current - item.price;
      _appendHistory(
        state,
        amount: -item.price,
        reason: '購買道具：${item.name}',
        type: 'expense',
      );
      await box.put('avatar_state', state);
    }

    // Add item to inventory
    await addConsumable(item.id, 1, reason: '購買');
    return true;
  }

  static void _appendHistory(
    Map<String, dynamic> state, {
    required int amount,
    required String reason,
    required String type,
  }) {
    final history = ((state['coinHistory'] as List?) ?? <dynamic>[])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    history.insert(0, {
      'amount': amount,
      'reason': reason,
      'type': type,
      'timestamp': DateTime.now().toIso8601String(),
    });

    if (history.length > 100) {
      history.removeRange(100, history.length);
    }
    state['coinHistory'] = history;
  }

  static void _ensureDefaults(Map<String, dynamic> state) {
    state['coins'] ??= _defaultCoins;
    state['selectedGender'] ??= 'male';
    state['selectedHairStyle'] ??= 'short';
    state['ownedItemIds'] ??= [
      'shirt_01',
      'pants_01',
      'shoes_01',
      'hat_01',
      'mask_01',
      'rod_01',
      'tackle_box_01',
      'cooler_01',
    ];
    state['equipped'] ??= {
      'shirt': 'shirt_01',
      'pants': 'pants_01',
      'shoes': 'shoes_01',
      'hat': 'hat_01',
      'mask': 'mask_01',
      'rod': 'rod_01',
      'tackle_box': 'tackle_box_01',
      'cooler': 'cooler_01',
    };
    state['consumables'] ??= {
      for (final item in gameShopItems)
        if (item.defaultQuantity > 0) item.id: item.defaultQuantity,
    };
  }

  static Future<Map<String, dynamic>> _loadState() async {
    final box = await Hive.openBox(_profileBoxName);
    final raw = box.get('avatar_state');
    if (raw is Map<String, dynamic>) return Map<String, dynamic>.from(raw);
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{};
  }
}
