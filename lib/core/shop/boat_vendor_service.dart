import 'package:hive/hive.dart';
import 'package:latlong2/latlong.dart';

import '../auth/local_account_service.dart';
import '../../domain/boat_vendor.dart';
import '../../features/profile/data/profile_wallet_service.dart';

class BoatVendorService {
  static const String _legacyBoxName = 'boat_vendor_box';
  static const String _accountBoxBaseName = 'boat_vendor';
  static const String _legacyMigrationKey = 'boat_vendor_legacy_migrated';
  static const String _activeVendorKey = 'active_boat_vendor_id';
  static const _boatSpotRadiusMeters = 100.0;

  static Box? _openedBox;
  static String? _openedBoxName;

  static Future<Box> get _box async {
    final boxName = LocalAccountService.boxNameFor(_accountBoxBaseName);
    if (_openedBox != null && _openedBox!.isOpen && _openedBoxName == boxName) {
      return _openedBox!;
    }

    _openedBox = await Hive.openBox(boxName);
    _openedBoxName = boxName;
    await _migrateLegacyBoxIfNeeded(_openedBox!);
    return _openedBox!;
  }

  /// Preserves data created before boat state became account-scoped.
  ///
  /// The old box was device-local, so it is copied once to the account that
  /// first opens the new namespace. It is never read again after migration.
  static Future<void> _migrateLegacyBoxIfNeeded(Box target) async {
    final markerBox = await Hive.openBox<dynamic>('local_accounts');
    if (markerBox.get(_legacyMigrationKey) == true) return;

    if (Hive.isBoxOpen(_legacyBoxName)) {
      final legacy = Hive.box<dynamic>(_legacyBoxName);
      for (final key in legacy.keys) {
        if (!target.containsKey(key)) {
          await target.put(key, legacy.get(key));
        }
      }
    } else {
      try {
        final legacy = await Hive.openBox<dynamic>(_legacyBoxName);
        for (final key in legacy.keys) {
          if (!target.containsKey(key)) {
            await target.put(key, legacy.get(key));
          }
        }
        await legacy.close();
      } catch (_) {
        // A missing legacy box is expected on new installs.
      }
    }

    await markerBox.put(_legacyMigrationKey, true);
  }

  /// Rent a boat vendor for the player. Deducts coins.
  /// Returns true on success, false if insufficient coins or vendor not found.
  static Future<bool> rent(String vendorId) async {
    final vendor = kBoatVendors.where((v) => v.id == vendorId).firstOrNull;
    if (vendor == null) return false;

    final box = await _box;
    final state = await _loadState(box);

    try {
      final updatedCoins = await ProfileWalletService.spendCoins(
        vendor.priceCoins,
        reason: '租用船家：${vendor.name}',
      );
      if (updatedCoins < 0) return false;
    } catch (_) {
      // Insufficient coins or error
      return false;
    }

    state[_activeVendorKey] = vendorId;
    await box.put('avatar_state', state);
    return true;
  }

  /// Returns the active vendor ID or null if none rented.
  static Future<String?> getActiveVendorId() async {
    final box = await _box;
    final state = await _loadState(box);
    return state[_activeVendorKey] as String?;
  }

  static Future<BoatVendor?> getActiveVendor() async {
    final vendorId = await getActiveVendorId();
    if (vendorId == null) return null;
    return _vendorById(vendorId);
  }

  static BoatVendor? _vendorById(String id) {
    return kBoatVendors.where((v) => v.id == id).firstOrNull;
  }

  /// Returns `List<LatLng>` for the active vendor spots, or empty list if none.
  static Future<List<LatLng>> getActiveSpots() async {
    final vendorId = await getActiveVendorId();
    if (vendorId == null) return [];
    final vendor = _vendorById(vendorId);
    return vendor?.spotLocations ?? [];
  }

  /// Returns a random dialogue from the active vendor, or null if none active.
  static Future<String?> getRandomDialogue() async {
    final vendorId = await getActiveVendorId();
    if (vendorId == null) return null;
    final vendor = _vendorById(vendorId);
    if (vendor == null || vendor.dialogues.isEmpty) return null;
    final idx = DateTime.now().millisecondsSinceEpoch % vendor.dialogues.length;
    return vendor.dialogues[idx];
  }

  /// Check if position is within about 100m of any active boat spot.
  static Future<bool> isAtBoatSpot(LatLng pos) async {
    final spots = await getActiveSpots();
    if (spots.isEmpty) return false;
    final distance = const Distance();
    for (final spot in spots) {
      final meters = distance.as(LengthUnit.Meter, pos, spot);
      if (meters <= _boatSpotRadiusMeters) {
        return true;
      }
    }
    return false;
  }

  /// Clear the active vendor rental.
  static Future<void> clearActive() async {
    final box = await _box;
    final state = await _loadState(box);
    state.remove(_activeVendorKey);
    await box.put('avatar_state', state);
  }

  static Future<Map<String, dynamic>> _loadState(Box box) async {
    final raw = box.get('avatar_state');
    if (raw is Map<String, dynamic>) return Map<String, dynamic>.from(raw);
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{};
  }

  /// Record result ('success' or 'fail') for a boat route spot.
  /// Returns true if the record was saved; false if spot was already attempted.
  static Future<bool> recordBoatSpotAttempt(
      String vendorId, int spotIndex, String result) async {
    if (result != 'success' && result != 'fail') return false;
    final box = await _box;
    final key = 'boat_spot_results_$vendorId';
    final stored = <String, String>{};
    final raw = box.get(key);
    if (raw is Map) {
      for (final entry in raw.entries) {
        if (entry.key is String && entry.value is String) {
          stored[entry.key as String] = entry.value as String;
        }
      }
    }
    if (stored.containsKey('$spotIndex')) return false; // already attempted
    stored['$spotIndex'] = result;
    await box.put(key, stored);
    return true;
  }

  /// Returns the persisted result for a boat route spot.
  ///
  /// Keeping the result, rather than only an attempted flag, lets the route
  /// screen show success and failure accurately after it is reopened.
  static Future<String?> getBoatSpotResult(
      String vendorId, int spotIndex) async {
    final box = await _box;
    final raw = box.get('boat_spot_results_$vendorId');
    if (raw is! Map) return null;
    final result = raw['$spotIndex'];
    return result is String && (result == 'success' || result == 'fail')
        ? result
        : null;
  }

  /// Returns true if this boat spot has already been attempted.
  static Future<bool> hasBoatSpotAttempted(
      String vendorId, int spotIndex) async {
    return await getBoatSpotResult(vendorId, spotIndex) != null;
  }
}
