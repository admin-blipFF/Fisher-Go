import 'package:hive/hive.dart';

class ProfileWalletService {
  static const _profileBoxName = 'profile_customization';
  static const _defaultCoins = 500;

  static Future<int> getCoins() async {
    final state = await _loadState();
    return (state['coins'] as num?)?.toInt() ?? _defaultCoins;
  }

  static Future<int> addCoins(int amount) async {
    final box = await Hive.openBox(_profileBoxName);
    final raw = box.get('avatar_state');
    final state = raw is Map<String, dynamic>
        ? Map<String, dynamic>.from(raw)
        : raw is Map
            ? Map<String, dynamic>.from(raw)
            : <String, dynamic>{};

    final current = (state['coins'] as num?)?.toInt() ?? _defaultCoins;
    final updated = current + amount;
    state['coins'] = updated;

    // Ensure minimum structure exists for first-time creation.
    state['selectedGender'] ??= 'other';
    state['selectedHairStyle'] ??= 'short';
    state['ownedItemIds'] ??= ['shirt_basic', 'pants_basic', 'shoes_basic'];
    state['equipped'] ??= {
      'shirt': 'shirt_basic',
      'pants': 'pants_basic',
      'shoes': 'shoes_basic',
    };

    await box.put('avatar_state', state);
    return updated;
  }

  static Future<Map<String, dynamic>> _loadState() async {
    final box = await Hive.openBox(_profileBoxName);
    final raw = box.get('avatar_state');
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return const {};
  }
}
