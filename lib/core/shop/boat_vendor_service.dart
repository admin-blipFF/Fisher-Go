import 'package:hive/hive.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/boat_vendor.dart';
import '../../features/profile/data/profile_wallet_service.dart';

class BoatVendorService {
  // Use a fixed (non-per-user) box so BoatRouteScreen reads the same data.
  static const String _boxName = 'boat_vendor_box';
  static const String _activeVendorKey = 'active_boat_vendor_id';
  static const _boatSpotRadiusMeters = 100.0;

  static Box? _openedBox;

  static Future<Box> get _box async {
    if (_openedBox != null && _openedBox!.isOpen) return _openedBox!;
    _openedBox = await Hive.openBox(_boxName);
    return _openedBox!;
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
    final stored =
        (box.get(key, defaultValue: <String, String>{}) as Map<String, String>);
    if (stored.containsKey('$spotIndex')) return false; // already attempted
    stored['$spotIndex'] = result;
    await box.put(key, stored);
    return true;
  }

  /// Returns true if this boat spot has already been attempted.
  static Future<bool> hasBoatSpotAttempted(
      String vendorId, int spotIndex) async {
    final box = await _box;
    final key = 'boat_spot_results_$vendorId';
    final stored =
        (box.get(key, defaultValue: <String, String>{}) as Map<String, String>);
    return stored.containsKey('$spotIndex');
  }
}
