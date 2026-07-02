import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:latlong2/latlong.dart' hide Path;
import '../../../core/announcement/announcement_service.dart';
import '../../../core/admin/admin_ops_service.dart';
import '../../../core/permissions/android_permission_gate.dart';
import '../../../core/shop/boat_vendor_service.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/tutorial/tutorial_service.dart';
import '../../../domain/boat_vendor.dart';
import '../../tutorial/presentation/tutorial_overlay.dart';
import '../../announcement/presentation/announcement_modal.dart';
import '../../catches/data/hk_fishing_spots_geocoded_seed.dart';
import '../../fish/domain/fish_collection_service.dart';
import '../../fish/domain/fish_collection_status.dart';
import '../domain/fishing_biome_rules.dart';
import '../domain/fishing_event_rules.dart';
import '../domain/fishing_spawn_rules.dart';
import '../domain/fishing_strike_rules.dart';
import '../domain/game_map_camera.dart';
import '../domain/game_map_feature_store.dart';
import '../domain/terrain_data_source.dart';
import '../../navigation/game_screen.dart';
import '../../profile/data/player_progress_service.dart';
import '../../profile/data/profile_wallet_service.dart';
import 'game_map_renderer.dart';

/// 地圖首頁
class GameHomeScreen extends StatefulWidget {
  const GameHomeScreen({
    super.key,
    required this.onOpenScreen,
    this.boatPromptNonce = 0,
  });
  final void Function(GameScreen) onOpenScreen;
  final int boatPromptNonce;
  @override
  State<GameHomeScreen> createState() => _GameHomeScreenState();
}

class _GameHomeScreenState extends State<GameHomeScreen>
    with TickerProviderStateMixin {
  // 無 GPS 權限時用青馬附近做可視 fallback，保留有道路、水域的首屏。
  static const _hkTerritoryCenter = LatLng(22.3517, 114.0743);

  bool _autoMode = false;
  LatLng _playerLatLng = _hkTerritoryCenter;
  bool _hasLiveLocation = false;
  double? _playerAccuracyMeters;
  int _baitCount = 0;
  bool _isLocating = false;
  _SpotDemo? _selectedSpot;
  bool _showMinigame = false;
  bool _showAnnouncementRedDot = false;
  bool _isStartupGateOpen = false;
  bool _isAdmin = false;
  TerrainDataSource _terrainDataSource = const LocalTerrainDataSource();
  bool _isTutorialFishing = false;
  Map<String, double> _fishBoosts = const {};
  bool _isAtBoatSpot = false;
  BoatVendor? _activeBoatVendor;
  List<LatLng> _cachedBoatSpots = [];
  double _mapBearingDegrees = 0;
  // 船家自動前進佇列
  List<_SpotDemo> _boatSpotQueue = [];
  int _boatSpotQueueIndex = -1;
  Map<int, String> _boatSpotResults = {}; // index -> 'success'/'fail'
  static String? _lastMinigameResult; // tree-shaker resistant static write
  static const double _spotDisplayRadiusMeters = 500;
  static const double _pierUnlockRadiusMeters = 80;
  static const double _islandSeaFishingRadiusMeters = 500;

  List<_SpotDemo> get _visibleSpots {
    return _nearbySpots
        .where((spot) =>
            _distanceMeters(_playerLatLng, LatLng(spot.lat, spot.lng)) <=
            _spotDisplayRadiusMeters)
        .toList();
  }

  double _distanceMeters(LatLng a, LatLng b) {
    return Geolocator.distanceBetween(
        a.latitude, a.longitude, b.latitude, b.longitude);
  }

  bool _canOpenSpot(_SpotDemo spot) {
    if (_hasLiveLocation &&
        _distanceMeters(_playerLatLng, LatLng(spot.lat, spot.lng)) <=
            _unlockRadiusMeters(spot)) {
      return true;
    }
    return false;
  }

  double _unlockRadiusMeters(_SpotDemo spot) =>
      spot.isNew ? _islandSeaFishingRadiusMeters : _pierUnlockRadiusMeters;

  late AnimationController _fishingController;
  late AnimationController _radarController;
  // 魚影視覺效果用 controller（同步但獨立 phase）
  late AnimationController _fishEffectController;
  // 隨機速度因子
  double _speedMultiplier = 1.0;

  // Public-pier coordinates are trusted for the live map. Island/rock/reef
  // points are only reintroduced through this hand-verified allowlist; the
  // remaining broad geocode seed stays hidden because many 洲/排/石 entries are
  // visually wrong.
  final List<_SpotDemo> _nearbySpots = [
    ...hkFishingSpotsGeocodedSeed.where((spot) => spot.type == 'pier').map(
          (spot) => _SpotDemo(
            spot.latitude,
            spot.longitude,
            spot.displayName,
            2,
            false,
          ),
        ),
    ..._developerTestSpots,
    ..._verifiedIslandRockSpots,
  ];

  Map<String, String> get _equipped => {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runStartupGate();
      _checkAnnouncementBadge();
      _loadActiveBoatVendor();
      _loadBait();
    });
    _claimAdminCoinGrants();
    _radarController =
        AnimationController(duration: const Duration(seconds: 3), vsync: this)
          ..repeat();
    _fishingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _fishEffectController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
    _fishingController.addListener(_onFishingTick);
    unawaited(_loadTerrainDataset());
    unawaited(_loadPlayerLocation());
  }

  Future<void> _loadTerrainDataset() async {
    try {
      final source =
          await rootBundle.loadString('assets/maps/hk_terrain_mvp.json');
      final dataset = GeoTerrainDataset.fromJson(source);
      if (!mounted) return;
      setState(() => _terrainDataSource = GeoTerrainDataSource(dataset));
    } catch (_) {
      if (!mounted) return;
      setState(() => _terrainDataSource = const LocalTerrainDataSource());
    }
  }

  @override
  void didUpdateWidget(covariant GameHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.boatPromptNonce != oldWidget.boatPromptNonce) {
      unawaited(_loadActiveBoatVendor(showPickerAfterLoad: true));
    }
  }

  Future<void> _runStartupGate() async {
    if (!mounted || _isStartupGateOpen) return;
    final shouldAskIdentity = await _shouldAskIdentityChoice();
    if (!mounted) return;
    if (shouldAskIdentity) {
      setState(() => _isStartupGateOpen = true);
      await _showIdentityChoiceDialog();
      if (!mounted) return;
      setState(() => _isStartupGateOpen = false);
    }
    await _checkAndShowTutorial();
  }

  Future<bool> _shouldAskIdentityChoice() async {
    if (SupabaseConfig.isConfigured) {
      // Supabase web restores the session from localStorage during startup.
      // Give it a short window before deciding the user is signed out.
      for (var i = 0; i < 10; i++) {
        if (Supabase.instance.client.auth.currentSession != null) {
          return false;
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
    final box = await Hive.openBox('startup_gate');
    return box.get('guest_mode_selected') != true;
  }

  Future<void> _setGuestModeSelected() async {
    final box = await Hive.openBox('startup_gate');
    await box.put('guest_mode_selected', true);
  }

  Future<void> _showIdentityChoiceDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        var loading = false;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('開始 FisherGO'),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('登入可雲端保存魚獲、金幣及裝備。'),
                SizedBox(height: 8),
                Text('訪客遊玩只會保存在此裝置，之後仍可再登入。'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: loading
                    ? null
                    : () {
                        Navigator.of(dialogContext).pop();
                        widget.onOpenScreen(GameScreen.profile);
                      },
                child: const Text('Email 登入/註冊'),
              ),
              TextButton(
                onPressed: loading
                    ? null
                    : () async {
                        await _setGuestModeSelected();
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }
                      },
                child: const Text('訪客遊玩'),
              ),
              FilledButton.icon(
                onPressed: loading || !SupabaseConfig.isConfigured
                    ? null
                    : () async {
                        setDialogState(() => loading = true);
                        try {
                          await Supabase.instance.client.auth.signInWithOAuth(
                            OAuthProvider.google,
                            redirectTo: 'https://fisher-go.app',
                          );
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Google 登入失敗：$e')),
                          );
                          setDialogState(() => loading = false);
                        }
                      },
                icon: loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.g_mobiledata, size: 28),
                label: Text(loading ? '登入中...' : 'Google 登入'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _loadAdminStateAndBoosts() async {
    final isAdmin = await AdminOpsService.isCurrentUserAdmin();
    final boosts = await AdminOpsService.activeFishBoosts();
    if (!mounted) return;
    setState(() {
      _isAdmin = isAdmin;
      _fishBoosts = boosts;
    });
  }

  Future<void> _claimAdminCoinGrants() async {
    final amount = await AdminOpsService.claimPendingCoinGrants();
    if (!mounted || amount <= 0) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已領取 Admin 派發金幣 +$amount')),
    );
  }

  Future<void> _checkAndShowTutorial() async {
    final done = await TutorialService.isCompleted();
    if (!done && mounted) {
      _showTutorialOverlay();
    }
  }

  Future<void> _checkAnnouncementBadge() async {
    final unseen = await AnnouncementService.hasUnseen();
    if (mounted) {
      setState(() => _showAnnouncementRedDot = unseen);
    }
  }

  Future<void> _loadActiveBoatVendor({bool showPickerAfterLoad = false}) async {
    final vendor = await BoatVendorService.getActiveVendor();
    if (!mounted) return;
    setState(() => _activeBoatVendor = vendor);
    if (showPickerAfterLoad && vendor != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showBoatSpotPicker();
      });
    }
  }

  Future<void> _loadBait() async {
    final count =
        await ProfileWalletService.getConsumableQuantity('basic_bait');
    if (!mounted) return;
    setState(() => _baitCount = count);
  }

  void _showBoatSpotPicker() {
    final vendor = _activeBoatVendor;
    if (vendor == null) return;

    // Build queue from all spots
    _boatSpotQueue = List.generate(vendor.spotLocations.length, (index) {
      final pos = vendor.spotLocations[index];
      final name = index < vendor.spotNames.length
          ? vendor.spotNames[index]
          : '船家釘點 ${index + 1}';
      return _SpotDemo(pos.latitude, pos.longitude, name, 3, false);
    });
    _boatSpotQueueIndex = 0;
    _boatSpotResults = {};

    // Start at first unplayed spot
    final firstSpot = _boatSpotQueue[0];
    setState(() {
      _selectedSpot = firstSpot;
      _playerLatLng = LatLng(firstSpot.lat, firstSpot.lng);
      _hasLiveLocation = true;
    });
    _openMinigame();
  }

  void _showTutorialOverlay() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => TutorialOverlay(
        onStartFishing: _startTutorialFishing,
        onComplete: () {
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _onFishingTick() {
    final tick = (_fishingController.value * 10).round();
    if (tick % 3 == 0) {
      final rng = math.Random();
      _speedMultiplier = 0.7 + rng.nextDouble() * 0.6;
      final duration = (900 / _speedMultiplier).round();
      _fishingController.duration = Duration(milliseconds: duration);
    }
  }

  void _startTutorialFishing() {
    Navigator.of(context).pop();
    const tutorialPier = _SpotDemo(
      22.291001,
      114.236315,
      '三家村碼頭',
      2,
      false,
    );
    setState(() {
      _selectedSpot = tutorialPier;
      _playerLatLng = const LatLng(22.291001, 114.236315);
      _hasLiveLocation = true;
      _isTutorialFishing = true;
    });
    _openMinigame();
  }

  @override
  void dispose() {
    _fishingController.removeListener(_onFishingTick);
    _radarController.dispose();
    _fishingController.dispose();
    _fishEffectController.dispose();
    super.dispose();
  }

  void _openMinigame() {
    if (!_isTutorialFishing && _baitCount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('紅蟲不足，請先到個人頁購買魚餌'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    unawaited(_grantFirstFishingAtSpotBonus());
    _speedMultiplier = 1.0;
    _fishingController.duration = const Duration(milliseconds: 900);
    if (!_fishingController.isAnimating) {
      _fishingController.repeat(reverse: true);
    }
    setState(() {
      _showMinigame = true;
    });
  }

  Future<void> _grantFirstFishingAtSpotBonus() async {
    final spot = _selectedSpot;
    if (spot == null) return;
    final key =
        '${spot.name}|${spot.lat.toStringAsFixed(6)}|${spot.lng.toStringAsFixed(6)}';
    final box = await Hive.openBox('spot_fishing_bonus');
    final now = DateTime.now();
    final rawLastClaimedAt = box.get(key);
    DateTime? lastClaimedAt;
    if (rawLastClaimedAt is String) {
      lastClaimedAt = DateTime.tryParse(rawLastClaimedAt);
    } else if (rawLastClaimedAt == true) {
      // Backward compatibility: old versions stored a boolean for once-ever
      // claims. Treat existing boolean claims as just claimed now so players
      // can receive this spot bonus again after the new cooldown.
      lastClaimedAt = now;
      await box.put(key, now.toIso8601String());
      return;
    }
    if (lastClaimedAt != null && now.difference(lastClaimedAt).inMinutes < 15) {
      return;
    }
    await box.put(key, now.toIso8601String());
    final updatedCoins = await ProfileWalletService.addCoins(
      10,
      reason: '釣點作釣獎勵：${spot.name}',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('在 ${spot.name} 作釣，獲得 +10 金幣（現有 $updatedCoins）'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _closeMinigame() {
    _fishingController.stop();
    setState(() {
      _showMinigame = false;

      _isTutorialFishing = false;
    });
    // Schedule boat queue auto-advance after overlay closes
    Future.delayed(const Duration(milliseconds: 100), _autoAdvanceIfNeeded);
  }

  // ==============================
  //  船家自動前進佇列
  // ==============================

  // ignore_for_file: unused_element
  // Prevent tree-shaking: called via nullable callback from _FishingOverlay
  @pragma('vm:entry-point')
  void _onBoatSpotResult(String result) {
    // Record result for current spot
    if (_boatSpotQueueIndex >= 0) {
      _boatSpotResults[_boatSpotQueueIndex] = result;
    }
    // Record to Hive
    if (_activeBoatVendor != null && _boatSpotQueueIndex >= 0) {
      BoatVendorService.recordBoatSpotAttempt(
          _activeBoatVendor!.id, _boatSpotQueueIndex, result);
    }

    // Show brief result toast then auto-advance
    final spotName =
        _boatSpotQueue.isNotEmpty && _boatSpotQueueIndex < _boatSpotQueue.length
            ? _boatSpotQueue[_boatSpotQueueIndex].name
            : '';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result == 'success' ? '✅ $spotName 成功！' : '❌ $spotName 失敗',
        ),
        duration: const Duration(seconds: 1),
      ),
    );

    // Advance to next spot after short delay
    Future.delayed(const Duration(milliseconds: 1200), _advanceToNextBoatSpot);
  }

  @pragma('vm:entry-point')
  void _advanceToNextBoatSpot() {
    if (!mounted) return;
    // Find next unplayed spot
    int nextIndex = _boatSpotQueueIndex + 1;
    while (nextIndex < _boatSpotQueue.length) {
      if (!_boatSpotResults.containsKey(nextIndex)) break;
      nextIndex++;
    }

    if (nextIndex >= _boatSpotQueue.length) {
      // All spots done — show completion and reset
      _showBoatRouteComplete();
      return;
    }

    // Start next spot
    final nextSpot = _boatSpotQueue[nextIndex];
    _boatSpotQueueIndex = nextIndex;
    setState(() {
      _selectedSpot = nextSpot;
      _playerLatLng = LatLng(nextSpot.lat, nextSpot.lng);
      _hasLiveLocation = true;
    });
    _openMinigame();
  }

  @pragma('vm:entry-point')
  void _showBoatRouteComplete() {
    _closeMinigame();
    final done = _boatSpotResults.length;
    final success = _boatSpotResults.values.where((v) => v == 'success').length;
    _boatSpotQueue = [];
    _boatSpotQueueIndex = -1;
    _boatSpotResults = {};
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🚤 路線完成！$done 個釘點，成功 $success 個'),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _autoAdvanceIfNeeded() {
    if (_boatSpotQueueIndex < 0) return;
    final result = _lastMinigameResult ?? "fail";
    _boatSpotResults[_boatSpotQueueIndex] = result;
    BoatVendorService.recordBoatSpotAttempt(
        _activeBoatVendor!.id, _boatSpotQueueIndex, result);
    // Advance to next spot after short delay
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) _advanceToNextBoatSpot();
    });
  }

  Future<void> _loadPlayerLocation() async {
    if (_isLocating) return;
    if (mounted) {
      setState(() => _isLocating = true);
    }
    try {
      final permission = await AndroidPermissionGate.run(() async {
        var current = await Geolocator.checkPermission();
        if (current == LocationPermission.denied) {
          current = await Geolocator.requestPermission();
        }
        return current;
      });
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      final latLng = LatLng(position.latitude, position.longitude);
      if (!mounted) return;
      setState(() {
        _playerLatLng = latLng;
        _hasLiveLocation = true;
        _playerAccuracyMeters = position.accuracy.isFinite
            ? position.accuracy.clamp(15, 2500).toDouble()
            : null;
      });
      await _refreshBoatSpotState();
    } catch (_) {
      // 測試環境、拒絕定位、瀏覽器未支援時保留香港中心 fallback。
    } finally {
      if (mounted) {
        setState(() => _isLocating = false);
      }
    }
  }

  Future<void> _refreshBoatSpotState() async {
    final spots = await BoatVendorService.getActiveSpots();
    final activeVendor = await BoatVendorService.getActiveVendor();
    final activeId = activeVendor?.id;
    if (!mounted || activeId == null) {
      if (mounted) {
        setState(() {
          _isAtBoatSpot = false;
          _activeBoatVendor = null;
          _cachedBoatSpots = [];
        });
      }
      return;
    }
    final distance = const Distance();
    final atSpot = spots
        .any((s) => distance.as(LengthUnit.Meter, _playerLatLng, s) <= 100);
    if (mounted) {
      setState(() {
        _isAtBoatSpot = atSpot;
        _activeBoatVendor = activeVendor;
        _cachedBoatSpots = spots;
      });
    }
  }

  _SpotDemo _buildBoatSpotDemo() => _SpotDemo(
        _cachedBoatSpots.first.latitude,
        _cachedBoatSpots.first.longitude,
        '船家釣點',
        3, // isNew = 3 means boat spot
        false,
      );

  void _openPanoramaMap() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _PanoramaMapSheet(
        spots: _nearbySpots,
        playerLatLng: _playerLatLng,
        hasLiveLocation: _hasLiveLocation,
        playerAccuracyMeters: _playerAccuracyMeters,
        equipped: _equipped,
        spotDisplayRadiusMeters: _spotDisplayRadiusMeters,
        rarityColor: _rarityColor,
        onSpotSelected: (spot) {
          Navigator.of(sheetContext).pop();
          if (!mounted) return;
          setState(() => _selectedSpot = spot);
        },
      ),
    );
  }

  void _rotateMapClockwise() {
    setState(() {
      _mapBearingDegrees = (_mapBearingDegrees + 45) % 360;
    });
  }

  void _rotateMapByDrag(DragUpdateDetails details) {
    setState(() {
      _mapBearingDegrees = (_mapBearingDegrees + details.delta.dx * 0.45) % 360;
      if (_mapBearingDegrees < 0) _mapBearingDegrees += 360;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 建立地圖 marker
    final visibleSpots = _visibleSpots;
    final selectedSpot = _selectedSpot;
    final selectedCanOpen = selectedSpot != null && _canOpenSpot(selectedSpot);
    final hasBait = _baitCount > 0;
    final nearestSpot = visibleSpots.isEmpty
        ? null
        : visibleSpots.reduce((a, b) =>
            _distanceMeters(_playerLatLng, LatLng(a.lat, a.lng)) <=
                    _distanceMeters(_playerLatLng, LatLng(b.lat, b.lng))
                ? a
                : b);

    final mapWorld = _GameWorldMapShell(
      spotCount: visibleSpots.length,
      hasLiveLocation: _hasLiveLocation,
      playerLatLng: _playerLatLng,
      spots: visibleSpots,
      terrainDataSource: _terrainDataSource,
      mapBearingDegrees: _mapBearingDegrees,
      onSpotSelected: (spot) => setState(() => _selectedSpot = spot),
    );

    return Scaffold(
      body: Stack(children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: _rotateMapByDrag,
          child: mapWorld,
        ),
        Center(
          child: IgnorePointer(
            child: _PlayerAvatar(
              equipped: _equipped,
              isLiveLocation: _hasLiveLocation,
            ),
          ),
        ),
        // 雷達格柵疊加（遊戲感）
        IgnorePointer(
          child: CustomPaint(
            size: Size.infinite,
            painter: _RadarGridPainter(),
          ),
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 12,
          right: 12,
          child: _TopStatusBar(
            spotCount: visibleSpots.length,
            autoEnabled: _autoMode,
            onToggleAuto: () => setState(() => _autoMode = !_autoMode),
            leadingLabel: 'Fisher Lv. 1',
            subtitleLabel: '探索水域',
          ),
        ),
        Positioned(
          left: 12,
          top: MediaQuery.of(context).padding.top + 66,
          child: _PanoramaMapButton(onTap: _openPanoramaMap),
        ),
        Positioned(
          left: 12,
          top: MediaQuery.of(context).padding.top + 118,
          child: _RotateMapButton(
            bearingDegrees: _mapBearingDegrees,
            onTap: _rotateMapClockwise,
          ),
        ),
        Positioned(
          right: 12,
          top: MediaQuery.of(context).size.height * 0.30,
          child: _SideButtons(
            onOpenScreen: widget.onOpenScreen,
            isAdmin: _isAdmin,
          ),
        ),
        Positioned(
          right: 12,
          bottom: MediaQuery.of(context).padding.bottom + 110,
          child: _LocateButton(
            isLocating: _isLocating,
            hasLiveLocation: _hasLiveLocation,
            accuracyMeters: _playerAccuracyMeters,
            onTap: _loadPlayerLocation,
          ),
        ),
        // Announcement bell — placed below the top status bar so it does not
        // cover radar/status information.
        Positioned(
          top: MediaQuery.of(context).padding.top + 62,
          right: 12,
          child: GestureDetector(
            onTap: () {
              AnnouncementModal.show(context);
              setState(() => _showAnnouncementRedDot = false);
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(color: Colors.black26, blurRadius: 6)
                    ],
                  ),
                  child: const Icon(Icons.notifications,
                      color: Colors.black54, size: 24),
                ),
                if (_showAnnouncementRedDot)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: MediaQuery.of(context).padding.bottom + 16,
          left: 16,
          right: 16,
          child: _BottomBar(
            hasCurrent: false,
            pendingCount: 0,
            baitSummary: '紅蟲 x$_baitCount',
            canFish: hasBait,
            onAddCheckpoint: () => widget.onOpenScreen(GameScreen.profile),
            onFishNearby: hasBait &&
                    (_activeBoatVendor != null ||
                        _isAtBoatSpot ||
                        (nearestSpot != null && _canOpenSpot(nearestSpot)))
                ? () {
                    if (_activeBoatVendor != null) {
                      _showBoatSpotPicker();
                      return;
                    }
                    final spotToUse =
                        (nearestSpot != null && _canOpenSpot(nearestSpot))
                            ? nearestSpot
                            : (_isAtBoatSpot ? _buildBoatSpotDemo() : null);
                    if (spotToUse != null) {
                      setState(() => _selectedSpot = spotToUse);
                      _openMinigame();
                    }
                  }
                : null,
          ),
        ),
        if (_selectedSpot != null)
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 100,
            left: 16,
            right: 16,
            child: _SpotDetailCard(
              spot: _selectedSpot!,
              onClose: () => setState(() => _selectedSpot = null),
              distanceMeters: _distanceMeters(
                _playerLatLng,
                LatLng(_selectedSpot!.lat, _selectedSpot!.lng),
              ),
              unlockRadiusMeters: _unlockRadiusMeters(_selectedSpot!),
              canStartFishing:
                  hasBait && (selectedCanOpen || _selectedSpot!.rarity == 3),
              onStartFishing:
                  hasBait && (selectedCanOpen || _selectedSpot!.rarity == 3)
                      ? _openMinigame
                      : null,
            ),
          ),
        if (_showMinigame)
          _FishingOverlay(
            spotName: _selectedSpot?.name ?? '附近釣點',
            spotBiome: _selectedSpot?.biome,
            tutorialMode: _isTutorialFishing,
            fishBoosts: _fishBoosts,
            onTutorialComplete: () {
              setState(() {
                _showMinigame = false;
                _isTutorialFishing = false;
              });
            },
            onClose: _closeMinigame,
            isIslandSpot: _selectedSpot?.isIsland ?? false,
            onMinigameResult:
                _boatSpotQueueIndex >= 0 ? _onBoatSpotResult : null,
          ),
      ]),
    );
  }

  Color _rarityColor(int rarity) {
    switch (rarity) {
      case 1:
        return Colors.green;
      case 2:
        return Colors.blue;
      case 3:
        return Colors.purple;
      case 4:
        return Colors.orange;
      case 5:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

// ==============================
//  魚類遊戲數據模型
// ==============================

enum _FishingPhase { spotSelect, waitingForBite, biteReady, fishing, result }

enum _FishRarity { common, rare, epic }

enum _FishBodySize { small, medium, large }

class _FishCombatStats {
  final double baseTension;
  final double stamina;
  final double spikePower;
  final double spikeDuration;
  const _FishCombatStats(
      {required this.baseTension,
      required this.stamina,
      required this.spikePower,
      required this.spikeDuration});
}

const _smallStats = _FishCombatStats(
    baseTension: 2, stamina: 80, spikePower: 6, spikeDuration: 1.5);
const _mediumStats = _FishCombatStats(
    baseTension: 4, stamina: 130, spikePower: 14, spikeDuration: 2.0);
const _largeStats = _FishCombatStats(
    baseTension: 7, stamina: 200, spikePower: 28, spikeDuration: 2.5);

/// 遊戲魚名 → 魚種數據庫 fishId 映射表
/// 修復：圖標 HK 英文名與 DB 中文名不一致，導致圖鑑錯亂
/// 遊戲魚名 → 魚種數據庫 fishId 映射表 (重排後新版 ID)
/// fishId 與 encyclopedia 完全同步，不再靠圖標檔名數字推導
const _gameNameToFishId = {
  '小沙丁': 'fish-007', // 沙甸魚/沙甸  Sardinella aurita
  '銀鱸魚': 'fish-040', // 銀鯧/白鯧     Pampus argenteus (silver pomfret)
  '烏頭': 'fish-063', // 灰烏頭/烏頭   Chelon labrosus (grey mullet)
  '大眼烏頭': 'fish-067', // 大鱗烏頭/大眼烏頭 Ellochelon vaigiensis
  '黃金沙丁': 'fish-146', // 金鰭鰺/金鰭瓜 Gnathanodon speciosus (golden trevally)
  '紅鰭魚': 'fish-065', // 花狗母魚/花狗母
  '花鱸': 'fish-060', // 金目鱸        Lates calcarifer (barramundi)
  '石斑魚': 'fish-073', // 橙點石斑/紅斑 Epinephelus coioides (orange-spotted grouper)
  '海塘蝨': 'fish-069', // 海鯰/海塘蝨   Genidens barbus (sea catfish)
  '七星鱸': 'fish-052', // 日本真鱸/海鱸 Lateolabrax japonicus (japanese seabass)
  '深海沙丁': 'fish-131', // 真池魚/巴浪    Trachurus japonicus
  '池仔': 'fish-135', // 脂眼凹肩鰺/鬼池魚
  '藍鰭鮪': 'fish-153', // 長尾吞拿/吞拿  Thunnus tonggol (longtail tuna)
  '深海鱈': 'fish-023', // 大頭帶魚/刀魚  Trichiurus lepturus
  '黃腳鱲': 'fish-109', // 黃鰭鯛/黃腳鱲
  '赤鱲': 'fish-103', // 赤鯛/赤鱲
  '黃雞魚': 'fish-101', // 約翰笛鯛/黃雞魚
  '金龍魚': 'fish-039', // 金線馬頭魚/紅衫馬頭 Nemipterus virgatus
  '終極鯊': 'fish-032', // 白點竹鯊/狗仔鯊 Chiloscyllium plagiosum
};

class _FishEntry {
  final String name;
  final _FishRarity rarity;
  final _FishBodySize bodySize;
  final int difficulty;
  final int reward;
  final String iconAsset;

  const _FishEntry({
    required this.name,
    required this.rarity,
    required this.bodySize,
    required this.difficulty,
    required this.reward,
    required this.iconAsset,
  });

  _FishCombatStats get stats {
    final base = switch (bodySize) {
      _FishBodySize.small => _smallStats,
      _FishBodySize.medium => _mediumStats,
      _FishBodySize.large => _largeStats,
    };
    final f = 1.0 + (difficulty - 1) * 0.15;
    return _FishCombatStats(
      baseTension: base.baseTension * f,
      stamina: base.stamina * f,
      spikePower: base.spikePower * f,
      spikeDuration: base.spikeDuration,
    );
  }

  String get fishId => _gameNameToFishId[name] ?? 'fish-022';

  String get silhouetteAsset => iconAsset
      .replaceFirst(
          'assets/fish/icons/generated/', 'assets/fish/icons/silhouettes/')
      .replaceFirst('.png', '_silhouette.png');

  String get bodySizeLabel => switch (bodySize) {
        _FishBodySize.small => '小型魚',
        _FishBodySize.medium => '中型魚',
        _FishBodySize.large => '大型魚',
      };
}

class _FishSpot {
  final String name;
  final double xMin;
  final double xMax;
  final List<_FishEntry> fish;
  final List<int> weights; // 與 fish 一一對應的抽選權重
  final int maxLineMeters;

  const _FishSpot({
    required this.name,
    required this.xMin,
    required this.xMax,
    required this.fish,
    required this.weights,
    required this.maxLineMeters,
  });
}

// 魚類數據定義
// 淺水：全小型魚，1% 稀有
const _fishIconDir = 'assets/fish/icons/generated';
const _tutorialFish = _FishEntry(
  name: '白䱛',
  rarity: _FishRarity.common,
  bodySize: _FishBodySize.small,
  difficulty: 1,
  reward: 8,
  iconAsset: '$_fishIconDir/010.png',
);
const _shallowFish = [
  _FishEntry(
      name: '小沙丁',
      rarity: _FishRarity.common,
      bodySize: _FishBodySize.small,
      difficulty: 1,
      reward: 5,
      iconAsset: '$_fishIconDir/034_hk-indian-mackerel.png'),
  _FishEntry(
      name: '銀鱸魚',
      rarity: _FishRarity.common,
      bodySize: _FishBodySize.small,
      difficulty: 1,
      reward: 6,
      iconAsset: '$_fishIconDir/039_hk-silver-pomfret.png'),
  _FishEntry(
      name: '烏頭',
      rarity: _FishRarity.common,
      bodySize: _FishBodySize.small,
      difficulty: 2,
      reward: 8,
      iconAsset: '$_fishIconDir/013_hk-grey-mullet.png'),
  _FishEntry(
      name: '大眼烏頭',
      rarity: _FishRarity.common,
      bodySize: _FishBodySize.small,
      difficulty: 2,
      reward: 10,
      iconAsset: '$_fishIconDir/014_hk-large-scale-mullet.png'),
  _FishEntry(
      name: '黃金沙丁',
      rarity: _FishRarity.epic,
      bodySize: _FishBodySize.small,
      difficulty: 3,
      reward: 60,
      iconAsset: '$_fishIconDir/030_hk-golden-trevally.png'),
];
const _shallowWeights = [28, 28, 25, 18, 1]; // 1% 稀有

// 中水：小型為主 + 中型
const _midFish = [
  _FishEntry(
      name: '紅鰭魚',
      rarity: _FishRarity.common,
      bodySize: _FishBodySize.small,
      difficulty: 2,
      reward: 10,
      iconAsset: '$_fishIconDir/005_hk-mangrove-red-snapper.png'),
  _FishEntry(
      name: '花鱸',
      rarity: _FishRarity.common,
      bodySize: _FishBodySize.small,
      difficulty: 2,
      reward: 12,
      iconAsset: '$_fishIconDir/016_hk-barramundi.png'),
  _FishEntry(
      name: '石斑魚',
      rarity: _FishRarity.rare,
      bodySize: _FishBodySize.medium,
      difficulty: 3,
      reward: 25,
      iconAsset: '$_fishIconDir/007_hk-orange-spotted-grouper.png'),
  _FishEntry(
      name: '海塘蝨',
      rarity: _FishRarity.rare,
      bodySize: _FishBodySize.medium,
      difficulty: 3,
      reward: 22,
      iconAsset: '$_fishIconDir/069.png'),
  _FishEntry(
      name: '七星鱸',
      rarity: _FishRarity.rare,
      bodySize: _FishBodySize.medium,
      difficulty: 4,
      reward: 30,
      iconAsset: '$_fishIconDir/015_hk-japanese-seabass.png'),
];
const _midWeights = [30, 30, 15, 10, 15];

// 深水：小型為主，30% 中型，5% 稀有大型
const _deepFish = [
  _FishEntry(
      name: '深海沙丁',
      rarity: _FishRarity.common,
      bodySize: _FishBodySize.small,
      difficulty: 3,
      reward: 18,
      iconAsset: '$_fishIconDir/032_hk-yellowtail-scad.png'),
  _FishEntry(
      name: '池仔',
      rarity: _FishRarity.common,
      bodySize: _FishBodySize.small,
      difficulty: 3,
      reward: 20,
      iconAsset: '$_fishIconDir/131_hk-真池魚-badge.png'),
  _FishEntry(
      name: '藍鰭鮪',
      rarity: _FishRarity.rare,
      bodySize: _FishBodySize.medium,
      difficulty: 4,
      reward: 50,
      iconAsset: '$_fishIconDir/037_hk-longtail-tuna.png'),
  _FishEntry(
      name: '深海鱈',
      rarity: _FishRarity.rare,
      bodySize: _FishBodySize.medium,
      difficulty: 4,
      reward: 45,
      iconAsset: '$_fishIconDir/018_hk-largehead-hairtail.png'),
  _FishEntry(
      name: '黃腳鱲',
      rarity: _FishRarity.rare,
      bodySize: _FishBodySize.medium,
      difficulty: 4,
      reward: 48,
      iconAsset: '$_fishIconDir/107.png'),
  _FishEntry(
      name: '赤鱲',
      rarity: _FishRarity.rare,
      bodySize: _FishBodySize.medium,
      difficulty: 4,
      reward: 48,
      iconAsset: '$_fishIconDir/099.png'),
  _FishEntry(
      name: '黃雞魚',
      rarity: _FishRarity.rare,
      bodySize: _FishBodySize.medium,
      difficulty: 4,
      reward: 52,
      iconAsset: '$_fishIconDir/095.png'),
  _FishEntry(
      name: '金龍魚',
      rarity: _FishRarity.epic,
      bodySize: _FishBodySize.large,
      difficulty: 5,
      reward: 100,
      iconAsset: '$_fishIconDir/024_hk-golden-threadfin-bream.png'),
  _FishEntry(
      name: '終極鯊',
      rarity: _FishRarity.epic,
      bodySize: _FishBodySize.large,
      difficulty: 5,
      reward: 150,
      iconAsset: '$_fishIconDir/045_hk-white-spotted-bamboo-shark.png'),
];
const _deepWeights = [48, 12, 10, 10, 5, 5, 5, 3, 2]; // 30% 中型、5% 稀有大型

const _allSpots = [
  _FishSpot(
      name: '淺水區',
      xMin: 0.0,
      xMax: 0.33,
      fish: _shallowFish,
      weights: _shallowWeights,
      maxLineMeters: 10),
  _FishSpot(
      name: '中水區',
      xMin: 0.33,
      xMax: 0.67,
      fish: _midFish,
      weights: _midWeights,
      maxLineMeters: 25),
  _FishSpot(
      name: '深水區',
      xMin: 0.67,
      xMax: 1.0,
      fish: _deepFish,
      weights: _deepWeights,
      maxLineMeters: 60),
];

// ==============================
//  魚類遊戲 Overlay (新)
// ==============================

class _FishingOverlay extends StatefulWidget {
  const _FishingOverlay({
    required this.spotName,
    required this.onClose,
    this.spotBiome,
    this.tutorialMode = false,
    this.fishBoosts = const {},
    this.onTutorialComplete,
    this.isIslandSpot = false,
    this.onMinigameResult,
  });
  final String spotName;
  final FishingSpotBiome? spotBiome;
  final VoidCallback onClose;
  final bool tutorialMode;
  final Map<String, double> fishBoosts;
  final VoidCallback? onTutorialComplete;
  final bool isIslandSpot;

  /// Called with 'success' or 'fail' when the result phase is shown.
  final void Function(String result)? onMinigameResult;

  @override
  State<_FishingOverlay> createState() => _FishingOverlayState();
}

class _FishingOverlayState extends State<_FishingOverlay>
    with TickerProviderStateMixin {
  static const _basicBaitId = 'basic_bait';

  _FishingPhase _phase = _FishingPhase.spotSelect;
  _FishSpot? _selectedSpot;
  _FishEntry? _caughtFish;
  bool? _fishingResult;
  bool _showResultDetails = false;
  Timer? _resultRevealTimer;
  Set<String> _knownFishIds = <String>{};
  String _failReason = '';

  // 張力遊戲狀態
  late AnimationController _tickController;
  double _tension = 40.0;
  double _fishStamina = 100.0;
  double _maxStamina = 100.0;
  double _lineMeters = 10.0;
  double _maxLineMeters = 10.0;
  bool _isSpiking = false;
  double _spikeTimer = 0;
  double _spikeCooldown = 2.0;
  bool _isPulling = false;
  bool _fishExhausted = false;
  int _tickCount = 0;
  int _gameSeconds = 0;
  double _hookOffset = 0.0;
  double _visualSeed = 0.0;
  double _biteWaitSeconds = 0.0;
  double _biteElapsedSeconds = 0.0;
  double _biteWindowSeconds = 1.4;
  int _lastBiteHapticTick = -1;
  final math.Random _rng = math.Random();

  @override
  void initState() {
    super.initState();
    _tickController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 50),
    )..addListener(_onTick);
    _loadKnownFish();
    if (widget.tutorialMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_startFishing(_allSpots[0]));
        }
      });
    }
  }

  Future<void> _loadKnownFish() async {
    final collection = await FishCollectionService.loadAllSafe();
    if (!mounted) return;
    setState(() {
      _knownFishIds = collection.entries
          .where((entry) =>
              entry.value.status.index >= FishDiscoveryStatus.gameCaught.index)
          .map((entry) => entry.key)
          .toSet();
    });
  }

  bool _hasCaughtBefore(_FishEntry? fish) {
    if (fish == null) return false;
    return _knownFishIds.contains(fish.fishId);
  }

  @override
  void dispose() {
    _resultRevealTimer?.cancel();
    _tickController.dispose();
    super.dispose();
  }

  void _onTick() {
    if (_phase == _FishingPhase.waitingForBite ||
        _phase == _FishingPhase.biteReady) {
      _onBiteTick();
      return;
    }
    if (_phase != _FishingPhase.fishing) return;
    final fish = _caughtFish;
    if (fish == null) return;
    final stats = fish.stats;
    const dt = 0.05;

    setState(() {
      _tickCount++;
      _gameSeconds = (_tickCount / 20).floor();

      final lineFactor = 0.6 + 0.8 * (1 - _lineMeters / _maxLineMeters);
      if (!_fishExhausted) {
        _tension += stats.baseTension * lineFactor * dt;
      }

      if (_isSpiking) {
        _tension += stats.spikePower * 0.35 * dt;
        _spikeTimer -= dt;
        if (_spikeTimer <= 0) {
          _isSpiking = false;
          _spikeCooldown = 3.5 + _rng.nextDouble() * 3;
        }
      } else {
        _spikeCooldown -= dt;
        if (_spikeCooldown <= 0 && _fishStamina > 5) {
          final chance = (_fishStamina / _maxStamina) * 0.7 + 0.1;
          if (_rng.nextDouble() < chance) {
            _isSpiking = true;
            _spikeTimer = stats.spikeDuration;
            _fishStamina -= 8;
            if (_fishStamina <= 0) {
              _fishStamina = 0;
              _fishExhausted = true;
              _isSpiking = false;
              _spikeTimer = 0;
            }
          } else {
            _spikeCooldown = 1.0;
          }
        }
      }

      if (_isPulling) {
        final reelSpeed = _fishExhausted ? 3.2 : 1.6;
        _tension += _fishExhausted ? 8 * dt : 14 * dt;
        _lineMeters -= reelSpeed * dt;
      } else {
        _tension -= 22 * dt;
      }

      final pullOut = _fishExhausted
          ? 0.1
          : stats.baseTension * 0.18 * (_isSpiking ? 2.0 : 1.0);
      _lineMeters += pullOut * dt;

      if (widget.tutorialMode) {
        _tension = _tension.clamp(0.0, 82.0);
        _lineMeters = _lineMeters.clamp(0.0, _maxLineMeters * 0.88);
      } else {
        _tension = _tension.clamp(0.0, 100.0);
        _lineMeters = _lineMeters.clamp(0.0, _maxLineMeters);
      }

      final staminaBeforeDrain = _fishStamina;
      if (!_fishExhausted) {
        _fishStamina -= 1.2 * dt;
        if (_tension >= 30 && _tension <= 70) {
          _fishStamina -= 2.2 * dt;
        }
      }
      _fishStamina = _fishStamina.clamp(0.0, _maxStamina);
      if (staminaBeforeDrain > 0 && _fishStamina <= 0) {
        _fishExhausted = true;
        _isSpiking = false;
        _spikeTimer = 0;
      }

      _hookOffset = ((_tension - 50) / 50).clamp(-1.0, 1.0);

      if (_fishExhausted && _lineMeters <= 0) {
        _endGame(true);
      } else if (!widget.tutorialMode && _tension >= 95) {
        _failReason = '張力太高，魚線斷了！';
        _endGame(false);
      } else if (!widget.tutorialMode && _lineMeters >= _maxLineMeters) {
        _failReason = '線全部放出，魚逃走了！';
        _endGame(false);
      }
    });
  }

  void _onBiteTick() {
    const dt = 0.05;
    setState(() {
      _tickCount++;
      _gameSeconds = (_tickCount / 20).floor();

      if (_phase == _FishingPhase.waitingForBite) {
        _biteElapsedSeconds += dt;
        _hookOffset = math.sin(_tickCount * 0.22) * 0.08;
        if (_biteElapsedSeconds >= _biteWaitSeconds) {
          _phase = _FishingPhase.biteReady;
          _biteElapsedSeconds = 0;
          _lastBiteHapticTick = -1;
          HapticFeedback.mediumImpact();
        }
        return;
      }

      _biteElapsedSeconds += dt;
      _hookOffset = math.sin(_tickCount * 1.65) * 0.9;
      if (_tickCount - _lastBiteHapticTick >= 5) {
        _lastBiteHapticTick = _tickCount;
        HapticFeedback.selectionClick();
      }
      if (_biteElapsedSeconds > _biteWindowSeconds) {
        _failReason = '太遲抽竿，魚食完餌走咗！';
        _endGame(false);
      }
    });
  }

  void _endGame(bool won) {
    _resultRevealTimer?.cancel();
    _fishingResult = won;
    _showResultDetails = false;
    _phase = _FishingPhase.result;
    _tickController.stop();

    // Fire result callback for auto-advance (boat vendor queue)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Store result in static field (tree-shaker resistant)
      _GameHomeScreenState._lastMinigameResult = won ? "success" : "fail";
      widget.onMinigameResult?.call(won ? 'success' : 'fail');
    });

    if (won && _caughtFish != null) {
      final fish = _caughtFish!;
      _checkAndLockTutorialFish(fish);
      _resultRevealTimer = Timer(const Duration(seconds: 1), () async {
        final isFirstCatch = !_hasCaughtBefore(fish);
        await FishCollectionService.markGameCaught(fish.fishId);
        PlayerCatchProgressResult? progressResult;
        int? updatedCoins;
        if (!widget.tutorialMode) {
          progressResult = await PlayerProgressService.recordGameCatch(
            fishId: fish.fishId,
            baseCoins: fish.reward,
            rarity: _progressRarityTier(fish.rarity),
            isFirstCatch: isFirstCatch,
          );
          updatedCoins = await ProfileWalletService.addCoins(
            progressResult.coinsGained,
            reason: '釣獲獎勵：${fish.name}',
          );
        }
        if (!mounted) return;
        setState(() {
          _knownFishIds = {..._knownFishIds, fish.fishId};
          _showResultDetails = true;
        });
        if (progressResult != null && updatedCoins != null) {
          _showProgressReward(progressResult, updatedCoins);
        }
        if (widget.tutorialMode && fish.fishId == 'fish-010') {
          await TutorialService.markCompleted();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('又係依D! #010 白䱛 已解鎖'),
              backgroundColor: Colors.teal,
              duration: Duration(seconds: 2),
            ),
          );
          Future.delayed(const Duration(milliseconds: 1800), () {
            if (mounted) widget.onTutorialComplete?.call();
          });
        }
      });
    } else {
      _showResultDetails = true;
      if (widget.tutorialMode) {
        _resultRevealTimer = Timer(const Duration(milliseconds: 1200), () {
          if (!mounted) return;
          unawaited(_startFishing(_selectedSpot ?? _allSpots[0]));
        });
      }
    }
  }

  void _showProgressReward(
    PlayerCatchProgressResult result,
    int updatedCoins,
  ) {
    final taskText = result.completedTasks.isEmpty
        ? ''
        : '｜任務 ${result.completedTasks.length}';
    final levelText = result.leveledUp ? '｜升到 Lv.${result.state.level}' : '';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '+${result.xpGained} XP｜+${result.coinsGained} 金幣$levelText$taskText'
          '｜現有 $updatedCoins',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  int _progressRarityTier(_FishRarity rarity) => switch (rarity) {
        _FishRarity.common => 1,
        _FishRarity.rare => 2,
        _FishRarity.epic => 3,
      };

  Future<void> _checkAndLockTutorialFish(_FishEntry fish) async {
    final tutorialDone = await TutorialService.isCompleted();
    if (!tutorialDone && fish.fishId != 'fish-010') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('先完成教學'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _startFishing(_FishSpot spot) async {
    if (!widget.tutorialMode) {
      final consumed = await ProfileWalletService.consumeConsumable(
        _basicBaitId,
        reason: '小遊戲開始消耗：紅蟲',
      );
      if (!consumed) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('紅蟲不足，請先到個人頁購買魚餌'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    final fish = _selectRandomFish(spot);
    if (!mounted) return;
    setState(() {
      _selectedSpot = spot;
      _caughtFish = fish;
      _phase = _FishingPhase.waitingForBite;
      _tension = 0.0;
      _maxStamina = fish.stats.stamina;
      _fishStamina = fish.stats.stamina;
      _maxLineMeters = spot.maxLineMeters.toDouble();
      _lineMeters = _maxLineMeters * 0.6;
      _isSpiking = false;
      _spikeTimer = 0;
      _spikeCooldown = 2.0;
      _fishExhausted = false;
      _tickCount = 0;
      _gameSeconds = 0;
      _hookOffset = 0.0;
      _visualSeed = _rng.nextDouble() * 1000;
      _biteWaitSeconds =
          widget.tutorialMode ? 0.8 : 1.8 + _rng.nextDouble() * 2.6;
      _biteElapsedSeconds = 0.0;
      _biteWindowSeconds = widget.tutorialMode ? 2.0 : 1.45;
      _lastBiteHapticTick = -1;
      _fishingResult = null;
      _showResultDetails = false;
      _failReason = '';
    });
    _tickController.repeat();
  }

  void _strikeHook() {
    final fish = _caughtFish;
    if (fish == null) return;

    if (_phase == _FishingPhase.waitingForBite) {
      HapticFeedback.lightImpact();
      _failReason = '太早抽竿，魚仲未食餌！';
      _endGame(false);
      return;
    }

    if (_phase != _FishingPhase.biteReady) return;

    final strike = FishingStrikeRules.evaluate(
      biteElapsedSeconds: _biteElapsedSeconds,
      biteWindowSeconds: _biteWindowSeconds,
      difficulty: fish.difficulty,
    );
    if (!strike.isSuccess) {
      HapticFeedback.lightImpact();
      _failReason = switch (strike.reason) {
        FishingStrikeFailReason.tooEarly => '太早抽竿，魚仲未咬實！',
        FishingStrikeFailReason.tooLate => '太遲抽竿，魚食完餌走咗！',
        null => '抽竿失手，魚甩咗！',
      };
      _endGame(false);
      return;
    }

    _beginFight();
  }

  void _beginFight() {
    final fish = _caughtFish;
    final spot = _selectedSpot;
    if (fish == null || spot == null) return;

    final stats = fish.stats;
    HapticFeedback.heavyImpact();
    setState(() {
      _phase = _FishingPhase.fishing;
      _tension = 40.0;
      _maxStamina = stats.stamina;
      _fishStamina = stats.stamina;
      _maxLineMeters = spot.maxLineMeters.toDouble();
      final minStart = _maxLineMeters * 0.35;
      final maxStart = _maxLineMeters * 0.85;
      _lineMeters = minStart + _rng.nextDouble() * (maxStart - minStart);
      _isSpiking = false;
      _spikeTimer = 0;
      _spikeCooldown = 2.0;
      _fishExhausted = false;
      _tickCount = 0;
      _gameSeconds = 0;
      _hookOffset = 0.0;
      _visualSeed = _rng.nextDouble() * 1000;
    });
  }

  void _onPullStart() {
    setState(() => _isPulling = true);
  }

  void _onPullEnd() {
    setState(() => _isPulling = false);
  }

  void _retry() {
    _resultRevealTimer?.cancel();
    setState(() {
      _phase = _FishingPhase.spotSelect;
      _caughtFish = null;
      _fishingResult = null;
      _showResultDetails = false;
    });
  }

  _FishEntry _selectRandomFish(_FishSpot spot) {
    if (widget.tutorialMode) return _tutorialFish;
    final now = DateTime.now();
    final adjustedWeights = List<double>.generate(spot.fish.length, (i) {
      final fish = spot.fish[i];
      final boost = widget.fishBoosts[fish.name] ?? 1.0;
      final locationBoost = FishingSpawnRules.locationMultiplier(
        spotName: widget.spotName,
        fishName: fish.name,
        fishId: fish.fishId,
        biome: widget.spotBiome,
        now: now,
      );
      return spot.weights[i] * boost * locationBoost;
    });
    final totalWeight = adjustedWeights.reduce((a, b) => a + b);
    var r = _rng.nextDouble() * totalWeight;
    for (var i = 0; i < spot.fish.length; i++) {
      r -= adjustedWeights[i];
      if (r <= 0) return spot.fish[i];
    }
    return spot.fish.last;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      // Dynamic scene background
      Image.asset(
        widget.isIslandSpot
            ? 'assets/fishing/scenes/island.png'
            : 'assets/fishing/scenes/pier.png',
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      ),
      Container(color: Colors.black.withValues(alpha: 0.55)),
      if (!widget.tutorialMode)
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          right: 8,
          child: SafeArea(
            child: IconButton.filled(
              onPressed: widget.onClose,
              icon: const Icon(Icons.close),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black54,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ),
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: _buildPhaseContent(context),
          ),
        ),
      ),
    ]);
  }

  Widget _buildPhaseContent(BuildContext context) {
    switch (_phase) {
      case _FishingPhase.spotSelect:
        return _buildSpotSelect(context);
      case _FishingPhase.waitingForBite:
      case _FishingPhase.biteReady:
        return _buildBitePhase(context);
      case _FishingPhase.fishing:
        return _buildFishingPhase(context);
      case _FishingPhase.result:
        return _buildResultPhase(context);
    }
  }

  Widget _buildSpotSelect(BuildContext context) {
    if (widget.tutorialMode) {
      return const Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.location_on, color: Colors.cyanAccent, size: 64),
        SizedBox(height: 16),
        Text(
          '教學碼頭位置',
          style: TextStyle(
              color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 8),
        Text(
          '三家村碼頭\n22.291001, 114.236315',
          style: TextStyle(color: Colors.white70, fontSize: 18, height: 1.4),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 16),
        Text(
          '正在強制開啟釣魚小遊戲…\n失敗會自動重試，直到成功釣到 #010 白䱛。',
          style:
              TextStyle(color: Colors.orangeAccent, fontSize: 15, height: 1.4),
          textAlign: TextAlign.center,
        ),
      ]);
    }
    final intelLabels = FishingSpawnRules.spotIntelLabels(widget.spotName);
    final eventLabels = FishingEventRules.activeEventLabels(
      spotName: widget.spotName,
      now: DateTime.now(),
    );
    return Column(mainAxisSize: MainAxisSize.min, children: [
      const Text(
        '🎣 選擇釣點',
        style: TextStyle(
            color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 4),
      Text(
        '${widget.spotName} · 選擇水域深度',
        style: const TextStyle(color: Colors.white70, fontSize: 14),
      ),
      if (intelLabels.isNotEmpty) ...[
        const SizedBox(height: 10),
        _spotIntelChips(intelLabels),
      ],
      if (eventLabels.isNotEmpty) ...[
        const SizedBox(height: 8),
        _spotEventChips(eventLabels),
      ],
      const SizedBox(height: 16),
      // 水域選擇 — 碼頭只有淺水；外島有淺/中/深三區
      if (!widget.isIslandSpot)
        _zoneCard(
          zone: _allSpots[0],
          icon: Icons.water,
          iconColor: Colors.greenAccent,
          badge: '常見',
          badgeColor: Colors.green,
          isLocked: false,
          onTap: () => unawaited(_startFishing(_allSpots[0])),
        )
      else
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            height: 280,
            width: double.infinity,
            child: Stack(fit: StackFit.expand, children: [
              Image.asset(
                'assets/minigame/scene_spot_select.webp',
                fit: BoxFit.cover,
              ),
              // 左區域 - 深水
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: MediaQuery.of(context).size.width * 0.33,
                child: _zoneCard(
                  zone: _allSpots[2],
                  icon: Icons.water,
                  iconColor: Colors.lightBlueAccent,
                  badge: '稀有·史詩',
                  badgeColor: Colors.purple,
                  isLocked: false,
                  onTap: () => unawaited(_startFishing(_allSpots[2])),
                ),
              ),
              // 中間區域 - 中水
              Positioned(
                left: MediaQuery.of(context).size.width * 0.33,
                top: 0,
                bottom: 0,
                width: MediaQuery.of(context).size.width * 0.34,
                child: _zoneCard(
                  zone: _allSpots[1],
                  icon: Icons.water,
                  iconColor: Colors.tealAccent,
                  badge: '普通·稀有',
                  badgeColor: Colors.blue,
                  isLocked: false,
                  onTap: () => unawaited(_startFishing(_allSpots[1])),
                ),
              ),
              // 右區域 - 淺水
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: MediaQuery.of(context).size.width * 0.33,
                child: _zoneCard(
                  zone: _allSpots[0],
                  icon: Icons.water,
                  iconColor: Colors.greenAccent,
                  badge: '常見',
                  badgeColor: Colors.green,
                  isLocked: false,
                  onTap: () => unawaited(_startFishing(_allSpots[0])),
                ),
              ),
            ]),
          ),
        ),
    ]);
  }

  Widget _spotIntelChips(List<String> labels) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final label in labels)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.cyanAccent.withValues(alpha: 0.16),
              border: Border.all(
                color: Colors.cyanAccent.withValues(alpha: 0.55),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.cyanAccent,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }

  Widget _spotEventChips(List<String> labels) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final label in labels)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.amberAccent.withValues(alpha: 0.16),
              border: Border.all(
                color: Colors.amberAccent.withValues(alpha: 0.62),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.bolt, color: Colors.amberAccent, size: 14),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.amberAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ]),
          ),
      ],
    );
  }

  Widget _buildBitePhase(BuildContext context) {
    final isBiting = _phase == _FishingPhase.biteReady;
    final progress = isBiting
        ? (_biteElapsedSeconds / _biteWindowSeconds).clamp(0.0, 1.0)
        : (_biteElapsedSeconds / _biteWaitSeconds).clamp(0.0, 1.0);
    final bobberScale =
        isBiting ? 1.0 + math.sin(_tickCount * 1.7).abs() * 0.18 : 1.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          isBiting ? '魚食餌！' : '等待魚食餌',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          isBiting ? '浮標急震，立即抽竿' : '${widget.spotName} · 放低魚餌等咬口',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isBiting ? Colors.orangeAccent : Colors.white70,
            fontSize: 14,
            fontWeight: isBiting ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            height: 300,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/minigame/scene_bobber_enhanced.webp',
                  fit: BoxFit.cover,
                ),
                Container(
                  color: Colors.black.withValues(alpha: isBiting ? 0.16 : 0.28),
                ),
                Positioned.fill(
                  child: CustomPaint(
                    painter: _HookPainter(
                      hookOffset: _hookOffset,
                      tension: isBiting ? 92 : 35,
                      tick: _tickCount,
                      seed: _visualSeed,
                      bodySize: _FishBodySize.small,
                    ),
                  ),
                ),
                Center(
                  child: Transform.translate(
                    offset: Offset(
                      0,
                      isBiting
                          ? math.sin(_tickCount * 1.7) * 36
                          : math.sin(_tickCount * 0.22) * 8,
                    ),
                    child: Transform.scale(
                      scale: bobberScale,
                      child: Icon(
                        Icons.radio_button_checked,
                        size: isBiting ? 86 : 64,
                        color:
                            isBiting ? Colors.orangeAccent : Colors.cyanAccent,
                        shadows: [
                          Shadow(
                            color: (isBiting
                                    ? Colors.orangeAccent
                                    : Colors.cyanAccent)
                                .withValues(alpha: 0.8),
                            blurRadius: isBiting ? 24 : 12,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 28,
                  right: 28,
                  bottom: 22,
                  child: Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: progress,
                      child: Container(
                        decoration: BoxDecoration(
                          color: isBiting
                              ? Colors.orangeAccent
                              : Colors.cyanAccent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _strikeHook,
          icon: const Icon(Icons.sports_martial_arts),
          label: Text(isBiting ? '抽竿！' : '抽竿'),
          style: ElevatedButton.styleFrom(
            backgroundColor: isBiting ? Colors.orangeAccent : Colors.white24,
            foregroundColor: isBiting ? Colors.black : Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 18),
            textStyle:
                const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isBiting ? '按得太遲會甩口' : '太早抽竿會嚇走條魚',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
      ],
    );
  }

  Widget _zoneCard({
    required _FishSpot zone,
    required IconData icon,
    required Color iconColor,
    required String badge,
    required Color badgeColor,
    required bool isLocked,
    required VoidCallback onTap,
  }) {
    // zone.rarity: 1=shallow, 2=mid, 3=deep → map to fish rarity tier
    int count;
    if (zone.name.contains('深')) {
      count = _deepFish.length;
    } else if (zone.name.contains('中')) {
      count = _midFish.length;
    } else {
      count = _shallowFish.length;
    }

    return GestureDetector(
      onTap: isLocked ? null : onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
            colors: [
              badgeColor.withValues(alpha: isLocked ? 0.1 : 0.35),
              Colors.transparent,
            ],
          ),
        ),
        child: Stack(
          children: [
            if (isLocked)
              Positioned(
                right: 4,
                top: 4,
                child: Icon(Icons.lock, color: Colors.white54, size: 16),
              ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon,
                      color: isLocked
                          ? iconColor.withValues(alpha: 0.4)
                          : iconColor,
                      size: 36),
                  const SizedBox(height: 6),
                  Text(
                    zone.name,
                    style: TextStyle(
                      color: isLocked ? Colors.white54 : Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      shadows: const [
                        Shadow(color: Colors.black, blurRadius: 4)
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: (isLocked ? badgeColor : badgeColor)
                          .withValues(alpha: isLocked ? 0.5 : 0.85),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isLocked ? '外島限定' : badge,
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isLocked ? '' : '$count 種魚',
                    style: TextStyle(
                        color: isLocked ? Colors.white38 : Colors.white70,
                        fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFishingPhase(BuildContext context) {
    final fish = _caughtFish;
    final staminaPct = (_fishStamina / _maxStamina).clamp(0.0, 1.0);
    final linePct = (_lineMeters / _maxLineMeters).clamp(0.0, 1.0);
    return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text(
              '🎣 ${_selectedSpot?.name ?? "釣魚中"}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '⏱ ${_gameSeconds ~/ 60}:${(_gameSeconds % 60).toString().padLeft(2, '0')}',
                style: const TextStyle(
                    color: Colors.cyanAccent,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
            ),
            if (fish != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getRarityColor(fish.rarity).withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  fish.bodySizeLabel,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ]),
          const SizedBox(height: 12),
          // 遊戲場景（張力計 + 魚鉤）
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              height: 300,
              width: double.infinity,
              child: Stack(fit: StackFit.expand, children: [
                Image.asset(
                  'assets/minigame/scene_bobber_enhanced.webp',
                  fit: BoxFit.cover,
                ),
                // 張力顯示
                Positioned(
                  left: 12,
                  top: 12,
                  bottom: 12,
                  width: 50,
                  child: CustomPaint(
                    painter: _TensionPainter(tension: _tension),
                  ),
                ),
                // 魚鉤 / 浮標 / 魚影視覺：覆蓋整個場景，不再只在右上角直線移動
                Positioned.fill(
                  child: CustomPaint(
                    painter: _HookPainter(
                      hookOffset: _hookOffset,
                      tension: _tension,
                      tick: _tickCount,
                      seed: _visualSeed,
                      bodySize: fish?.bodySize ?? _FishBodySize.medium,
                    ),
                  ),
                ),
                // 線長條（頂部）
                Positioned(
                  left: 80,
                  right: 80,
                  top: 14,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(
                      '🎣 距離 ${_lineMeters.toStringAsFixed(1)}m / ${_maxLineMeters.toInt()}m',
                      style: TextStyle(
                        color: linePct > 0.8 ? Colors.redAccent : Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        shadows: const [
                          Shadow(color: Colors.black, blurRadius: 3)
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: linePct,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: linePct > 0.8
                                  ? [Colors.redAccent, Colors.deepOrange]
                                  : _fishExhausted
                                      ? [Colors.greenAccent, Colors.lightGreen]
                                      : [Colors.cyanAccent, Colors.blueAccent],
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _fishExhausted
                          ? '魚已力竭：收線速度 x2'
                          : '收線至 0 = 釣上 | 距離爆滿 = 魚走',
                      style: TextStyle(
                        color: _fishExhausted
                            ? Colors.greenAccent
                            : Colors.white70,
                        fontSize: 9,
                        fontWeight: _fishExhausted
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ]),
                ),
                // 魚體力進度條（底部）
                Positioned(
                  left: 80,
                  right: 80,
                  bottom: 16,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(
                      '🐟 ${_hasCaughtBefore(fish) ? fish!.name : "？？？"} 體力',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Stack(children: [
                        FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: staminaPct,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: staminaPct > 0.5
                                    ? [Colors.lightGreenAccent, Colors.green]
                                    : [Colors.orange, Colors.redAccent],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        Center(
                          child: Text(
                            '${(_fishStamina).toInt()} / ${_maxStamina.toInt()}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(color: Colors.black, blurRadius: 2)
                              ],
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ]),
                ),
                // 暴衝提示
                if (_isSpiking)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 70,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.red.withValues(alpha: 0.5),
                                blurRadius: 16,
                                spreadRadius: 2),
                          ],
                        ),
                        child: Text(
                          '⚡ 魚爆衝中！放手卸力！(${_spikeTimer.toStringAsFixed(1)}s)',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          // 張力提示
          Text(
            _fishExhausted
                ? '✅ 魚已力竭！按住快速收線上魚'
                : _tension >= 90
                    ? '⚠️ 張力過高！線要斷了！快放手！'
                    : _isSpiking
                        ? '⚡ 魚爆衝！放手等佢過'
                        : linePct > 0.8
                            ? '⚠️ 魚快拉到最遠！快啲收線！'
                            : _tension >= 70
                                ? '⚡ 張力偏高，留意爆衝'
                                : '✅ 按住收線，爆衝時放手',
            style: TextStyle(
              color: _fishExhausted
                  ? Colors.greenAccent
                  : _tension >= 90 || linePct > 0.8
                      ? Colors.redAccent
                      : _isSpiking || _tension >= 70
                          ? Colors.orangeAccent
                          : Colors.greenAccent,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          // 拉竿按鈕
          GestureDetector(
            onTapDown: (_) => _onPullStart(),
            onTapUp: (_) => _onPullEnd(),
            onTapCancel: _onPullEnd,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _isPulling ? Colors.redAccent : Colors.cyanAccent,
                    _isPulling ? Colors.deepOrange : Colors.blueAccent,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: (_isPulling ? Colors.redAccent : Colors.cyanAccent)
                        .withValues(alpha: 0.6),
                    blurRadius: _isPulling ? 30 : 20,
                    spreadRadius: _isPulling ? 5 : 2,
                  ),
                ],
              ),
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    Icons.phishing,
                    color: Colors.white,
                    size: _isPulling ? 60 : 50,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isPulling ? '收線中！' : '收線',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '按住收線（張力升）· 放手卸力（魚拉線出去）',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ]);
  }

  Widget _buildResultPhase(BuildContext context) {
    final won = _fishingResult == true;

    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(
        won ? '🎉 成功上鉤！' : '🐟 魚跑掉了...',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
      ),
      if (!won && _failReason.isNotEmpty) ...[
        const SizedBox(height: 6),
        Text(
          _failReason,
          style: const TextStyle(color: Colors.orangeAccent, fontSize: 14),
        ),
      ],
      const SizedBox(height: 16),
      // 結果圖像
      ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          height: 200,
          width: double.infinity,
          child: Stack(fit: StackFit.expand, children: [
            Image.asset(
              won
                  ? 'assets/minigame/scene_catch_success.webp'
                  : 'assets/minigame/scene_bobber_enhanced.webp',
              fit: BoxFit.cover,
            ),
            if (won && _caughtFish != null && _showResultDetails)
              Positioned.fill(
                child: Center(
                  child: Image.asset(
                    _caughtFish!.silhouetteAsset,
                    width: 190,
                    height: 190,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.set_meal,
                      color: Colors.white54,
                      size: 80,
                    ),
                  ),
                ),
              ),
          ]),
        ),
      ),

      if (won && _caughtFish != null && _showResultDetails) ...[
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
              _caughtFish!.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                _resultChip(
                  label: _getRarityLabel(_caughtFish!.rarity),
                  color: _getRarityColor(_caughtFish!.rarity),
                  textColor: Colors.white,
                ),
                _resultChip(
                  label: _caughtFish!.bodySizeLabel,
                  color: _getRarityColor(_caughtFish!.rarity)
                      .withValues(alpha: 0.85),
                  textColor: Colors.white,
                ),
                _resultChip(
                  label: '難${_caughtFish!.difficulty}',
                  color: Colors.black54,
                  textColor: Colors.white70,
                ),
                _resultChip(
                  label: '+${_caughtFish!.reward}',
                  color: Colors.amber.withValues(alpha: 0.85),
                  textColor: Colors.white,
                  icon: Icons.monetization_on,
                ),
              ],
            ),
          ]),
        ),
      ],
      const SizedBox(height: 20),
      // 按鈕列
      Row(mainAxisSize: MainAxisSize.min, children: [
        OutlinedButton(
          onPressed: _retry,
          child: const Text('再試'),
        ),
        const SizedBox(width: 14),
        ElevatedButton.icon(
          onPressed: widget.onClose,
          icon: const Icon(Icons.map),
          label: const Text('返回地圖'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 13),
            textStyle:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ]),
    ]);
  }

  Widget _resultChip({
    required String label,
    required Color color,
    required Color textColor,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, color: textColor, size: 14),
          const SizedBox(width: 3),
        ],
        Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ]),
    );
  }

  Color _getRarityColor(_FishRarity rarity) {
    switch (rarity) {
      case _FishRarity.common:
        return Colors.green;
      case _FishRarity.rare:
        return Colors.blue;
      case _FishRarity.epic:
        return Colors.purple;
    }
  }

  String _getRarityLabel(_FishRarity rarity) {
    switch (rarity) {
      case _FishRarity.common:
        return '普通';
      case _FishRarity.rare:
        return '稀有';
      case _FishRarity.epic:
        return '史詩';
    }
  }
}

// ==============================
//  張力計 Painter
// ==============================

class _TensionPainter extends CustomPainter {
  const _TensionPainter({required this.tension});

  final double tension;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(12));

    // 背景
    canvas.drawRRect(rrect, Paint()..color = Colors.black54);

    // 張力條（從下往上）
    final barHeight = size.height - 24;
    final barWidth = size.width - 8;
    final barLeft = 4.0;
    final barBottom = size.height - 4;

    // 繪製顏色區域
    // 紅色區域（危險）
    canvas.drawRect(
      Rect.fromLTWH(
          barLeft, barBottom - barHeight * 0.1, barWidth, barHeight * 0.1),
      Paint()..color = Colors.redAccent.withValues(alpha: 0.5),
    );
    // 黃色區域（左）
    canvas.drawRect(
      Rect.fromLTWH(
          barLeft, barBottom - barHeight * 0.3, barWidth, barHeight * 0.2),
      Paint()..color = Colors.yellowAccent.withValues(alpha: 0.5),
    );
    // 綠色區域（中間）
    canvas.drawRect(
      Rect.fromLTWH(
          barLeft, barBottom - barHeight * 0.7, barWidth, barHeight * 0.4),
      Paint()..color = Colors.greenAccent.withValues(alpha: 0.5),
    );
    // 黃色區域（右）
    canvas.drawRect(
      Rect.fromLTWH(
          barLeft, barBottom - barHeight * 0.9, barWidth, barHeight * 0.2),
      Paint()..color = Colors.yellowAccent.withValues(alpha: 0.5),
    );
    // 紅色區域（右）
    canvas.drawRect(
      Rect.fromLTWH(
          barLeft, barBottom - barHeight * 1.0, barWidth, barHeight * 0.1),
      Paint()..color = Colors.redAccent.withValues(alpha: 0.5),
    );

    // 當前張力指示線
    final tensionHeight = (tension / 100.0) * barHeight;
    final lineY = barBottom - tensionHeight;

    // 指示線發光
    final lineColor = _getTensionColor(tension);
    final glowPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawLine(
      Offset(0, lineY),
      Offset(size.width, lineY),
      glowPaint..strokeWidth = 8,
    );

    // 指示線本體
    canvas.drawLine(
      Offset(0, lineY),
      Offset(size.width, lineY),
      Paint()
        ..color = lineColor
        ..strokeWidth = 3,
    );

    // 三角形指示器
    final path = Path()
      ..moveTo(barLeft - 6, lineY)
      ..lineTo(barLeft - 2, lineY - 5)
      ..lineTo(barLeft - 2, lineY + 5)
      ..close();
    canvas.drawPath(path, Paint()..color = lineColor);

    // 張力數值
    final textPainter = TextPainter(
      text: TextSpan(
        text: '${tension.toInt()}',
        style: TextStyle(
          color: lineColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(
          (size.width - textPainter.width) / 2, lineY - textPainter.height - 8),
    );

    // 標籤
    final labelPainter = TextPainter(
      text: const TextSpan(
        text: '張力',
        style: TextStyle(
          color: Colors.white70,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    labelPainter.paint(
      canvas,
      Offset((size.width - labelPainter.width) / 2,
          size.height - labelPainter.height - 2),
    );
  }

  Color _getTensionColor(double t) {
    if (t >= 90 || t <= 10) return Colors.redAccent;
    if (t >= 70 || t <= 30) return Colors.yellowAccent;
    return Colors.greenAccent;
  }

  @override
  bool shouldRepaint(covariant _TensionPainter old) => old.tension != tension;
}

// ==============================
//  魚鉤視覺 Painter
// ==============================

class _HookPainter extends CustomPainter {
  const _HookPainter({
    required this.hookOffset,
    required this.tension,
    required this.tick,
    required this.seed,
    required this.bodySize,
  });

  final double hookOffset; // -1.0 to 1.0
  final double tension;
  final int tick;
  final double seed;
  final _FishBodySize bodySize;

  @override
  void paint(Canvas canvas, Size size) {
    // 留出 HUD 空間：上方距離條、左方張力條、下方體力條
    final safeLeft = 78.0;
    final safeRight = size.width - 22.0;
    final waterTop = 78.0;
    final waterBottom = size.height - 72.0;
    final waterWidth = safeRight - safeLeft;
    final waterHeight = waterBottom - waterTop;

    final t = tick * 0.05 + seed;
    final slowDrift =
        math.sin(t * 0.53) * 0.18 + math.sin(t * 0.91 + 1.8) * 0.09;
    final microJitter =
        math.sin(t * 4.6 + 0.7) * 0.018 + math.sin(t * 7.9 + 2.1) * 0.011;
    final dartPulse = math.sin(t * 0.37 + seed).abs() > 0.93
        ? math.sin(t * 12.0) * 0.10
        : 0.0;
    final visualX = (slowDrift + microJitter + dartPulse).clamp(-0.38, 0.38);
    final visualY =
        (math.sin(t * 0.67 + 2.2) * 0.13 + math.sin(t * 1.31) * 0.06)
            .clamp(-0.23, 0.23);

    // hookOffset 仍反映張力，但只影響大方向；視覺漂移在 2D 水域內自由移動
    final tensionBias = hookOffset.clamp(-1.0, 1.0);
    final bobberX =
        safeLeft + waterWidth * (0.56 + visualX + tensionBias * 0.07);
    final bobberY = waterTop +
        waterHeight * (0.22 + visualY * 0.35) +
        math.sin(t * 1.9) * 3.5 +
        math.sin(t * 3.4 + 1.2) * 1.8;

    final fishX =
        safeLeft + waterWidth * (0.50 + visualX * 1.25 + tensionBias * 0.16);
    final fishY = waterTop +
        waterHeight * (0.72 + visualY * 0.75) +
        math.sin(t * 1.11 + 2.4) * 4.5;

    final bobberCenter = Offset(
      bobberX.clamp(safeLeft + 22, safeRight - 22),
      bobberY.clamp(waterTop + 12, waterTop + waterHeight * 0.55),
    );
    final fishCenter = Offset(
      fishX.clamp(safeLeft + 44, safeRight - 44),
      fishY.clamp(waterTop + waterHeight * 0.45, waterBottom - 14),
    );

    final prevT = t - 0.05;
    final prevVisualX = (math.sin(prevT * 0.53) * 0.18 +
            math.sin(prevT * 0.91 + 1.8) * 0.09 +
            math.sin(prevT * 4.6 + 0.7) * 0.018 +
            math.sin(prevT * 7.9 + 2.1) * 0.011)
        .clamp(-0.38, 0.38);
    final prevVisualY =
        (math.sin(prevT * 0.67 + 2.2) * 0.13 + math.sin(prevT * 1.31) * 0.06)
            .clamp(-0.23, 0.23);
    final prevFishCenter = Offset(
      (safeLeft + waterWidth * (0.50 + prevVisualX * 1.25 + tensionBias * 0.16))
          .clamp(safeLeft + 44, safeRight - 44),
      (waterTop +
              waterHeight * (0.72 + prevVisualY * 0.75) +
              math.sin(prevT * 1.11 + 2.4) * 4.5)
          .clamp(waterTop + waterHeight * 0.45, waterBottom - 14),
    );
    final fishVelocity = fishCenter - prevFishCenter;

    // 背景魚群：多條遠處魚影以不同速度/深度隨機游動，增加水中生命感。
    _drawBackgroundFishSchool(
      canvas,
      Rect.fromLTRB(safeLeft, waterTop, safeRight, waterBottom),
      t,
    );

    // 魚線：由畫面上方自然垂下，有弧度，不再是右上死直線
    final rodTip = Offset(size.width * 0.72, 34);
    final controlA = Offset(
      rodTip.dx + math.sin(t * 0.61) * 18,
      waterTop * 0.76,
    );
    final controlB = Offset(
      bobberCenter.dx - 34 + math.sin(t * 0.83 + 1.6) * 12,
      bobberCenter.dy - 42,
    );
    final linePath = Path()
      ..moveTo(rodTip.dx, rodTip.dy)
      ..cubicTo(controlA.dx, controlA.dy, controlB.dx, controlB.dy,
          bobberCenter.dx, bobberCenter.dy - 8);
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.64)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawPath(linePath, linePaint);

    // 浮標：在水面 2D 漂移，帶水波/陰影/高光
    final ripplePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = Colors.white.withValues(alpha: 0.22);
    canvas.drawOval(
      Rect.fromCenter(center: bobberCenter, width: 58, height: 16),
      ripplePaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: bobberCenter, width: 36, height: 10),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.cyanAccent.withValues(alpha: 0.20),
    );

    final bobberShadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(bobberCenter.translate(2, 3), 13, bobberShadow);

    final bobberTop = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.white, Color(0xFFFFF3E0)],
      ).createShader(Rect.fromCircle(center: bobberCenter, radius: 13));
    final bobberBottom = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFF5252), Color(0xFFB71C1C)],
      ).createShader(Rect.fromCircle(center: bobberCenter, radius: 13));
    canvas.drawArc(Rect.fromCircle(center: bobberCenter, radius: 13), math.pi,
        math.pi, true, bobberTop);
    canvas.drawArc(Rect.fromCircle(center: bobberCenter, radius: 13), 0,
        math.pi, true, bobberBottom);
    canvas.drawCircle(bobberCenter.translate(-4, -5), 3,
        Paint()..color = Colors.white.withValues(alpha: 0.85));

    // 主魚影：依魚類體形縮放，小型=原本 30%、中型=60%、大型=100%。
    // 魚頭方向跟隨移動向量，模擬真實游動，不再固定方向。
    final sizeFactor = switch (bodySize) {
      _FishBodySize.small => 0.30,
      _FishBodySize.medium => 0.60,
      _FishBodySize.large => 1.00,
    };
    final baseLength = 104.0 + (tension.clamp(0, 100) / 100) * 18;
    final baseHeight = 28.0;
    final angle = fishVelocity.distance > 0.1
        ? math.atan2(fishVelocity.dy, fishVelocity.dx)
        : math.sin(t * 0.8) * 0.15;
    _drawFishSilhouette(
      canvas,
      center: fishCenter,
      length: baseLength * sizeFactor,
      height: baseHeight * sizeFactor,
      angle: angle,
      alpha: 0.30,
      blur: 5.0,
      tailBeat: math.sin(t * 7.2) * 0.55,
    );
  }

  void _drawBackgroundFishSchool(Canvas canvas, Rect water, double t) {
    for (var i = 0; i < 11; i++) {
      final phase = seed * (0.17 + i * 0.031) + i * 1.973;
      final leftToRight = i.isEven;
      final speed = 0.055 + (i % 5) * 0.014;
      final progress = (t * speed + phase).abs() % 1.0;
      final xNorm = leftToRight ? progress : 1.0 - progress;
      final yNorm = 0.18 + ((math.sin(phase * 2.1) + 1) / 2) * 0.68;
      final center = Offset(
        water.left + water.width * xNorm,
        water.top + water.height * yNorm + math.sin(t * 0.7 + phase) * 7,
      );
      final length = (22.0 + (i % 4) * 7.0) * (0.75 + yNorm * 0.45);
      final height = length * 0.28;
      final angle = leftToRight
          ? math.sin(t * 0.6 + phase) * 0.10
          : math.pi + math.sin(t * 0.6 + phase) * 0.10;
      _drawFishSilhouette(
        canvas,
        center: center,
        length: length,
        height: height,
        angle: angle,
        alpha: 0.08 + (i % 3) * 0.025,
        blur: 2.6,
        tailBeat: math.sin(t * (4.0 + i * 0.2) + phase) * 0.40,
      );
    }
  }

  void _drawFishSilhouette(
    Canvas canvas, {
    required Offset center,
    required double length,
    required double height,
    required double angle,
    required double alpha,
    required double blur,
    required double tailBeat,
  }) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: alpha)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);

    // Local +X is fish head direction. Tail stays at -X, so rotation makes
    // the fish point along its movement vector.
    final body = Path()
      ..moveTo(length * 0.50, 0)
      ..quadraticBezierTo(
          length * 0.28, -height * 0.95, -length * 0.26, -height * 0.72)
      ..quadraticBezierTo(-length * 0.52, 0, -length * 0.26, height * 0.72)
      ..quadraticBezierTo(length * 0.28, height * 0.95, length * 0.50, 0)
      ..close();
    canvas.drawPath(body, paint);

    final tail = Path()
      ..moveTo(-length * 0.42, 0)
      ..lineTo(-length * 0.70, -height * (0.78 + tailBeat.abs() * 0.18))
      ..lineTo(-length * 0.62, tailBeat * height * 0.22)
      ..lineTo(-length * 0.70, height * (0.78 + tailBeat.abs() * 0.18))
      ..close();
    canvas.drawPath(tail, paint);

    final finPaint = Paint()
      ..color = Colors.black.withValues(alpha: alpha * 0.72)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur * 0.65);
    final fin = Path()
      ..moveTo(-length * 0.02, height * 0.52)
      ..lineTo(-length * 0.18, height * 1.10)
      ..lineTo(length * 0.12, height * 0.48)
      ..close();
    canvas.drawPath(fin, finPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HookPainter old) =>
      old.hookOffset != hookOffset ||
      old.tension != tension ||
      old.tick != tick ||
      old.seed != seed ||
      old.bodySize != bodySize;
}

// ==============================
//  地圖其餘 Widget（不變）
// ==============================

class _SpotDemo {
  final double lat, lng;
  final String name;
  final int rarity;
  final bool isNew;
  final bool isIsland;

  const _SpotDemo(this.lat, this.lng, this.name, this.rarity, this.isNew)
      : isIsland = rarity >= 4;

  FishingSpotBiome get biome => FishingBiomeRules.inferSpotBiome(
        spotName: name,
        isIsland: isIsland,
        isBoat: rarity == 3,
      );
}

// First verified island/rock batch. Coordinates are deliberately explicit
// overrides, not edits to the raw seed, so unverified island geocodes remain
// quarantined. Sources checked against OSM/Nominatim names and existing
// map.gov-derived points where available.
const List<_SpotDemo> _verifiedIslandRockSpots = [
  _SpotDemo(22.2482972, 114.2894804, '東龍洲', 4, true),
  _SpotDemo(22.2568111, 114.3502808, '果洲群島', 5, true),
  _SpotDemo(22.3139519, 114.3652149, '火石洲', 5, true),
  _SpotDemo(22.2311512, 114.1604096, '鴨脷排', 4, true),
  _SpotDemo(22.5516886, 114.2693804, '鴨洲', 4, true),
  _SpotDemo(22.4757176, 114.3618788, '塔門', 4, true),
  _SpotDemo(22.3269133, 114.2970717, '牛尾洲', 4, true),
  _SpotDemo(22.3614829, 114.3126306, '滘西洲', 4, true),
  _SpotDemo(22.3340439, 114.3635557, '伙頭墳洲', 5, true),
  _SpotDemo(22.3636881, 114.3915044, '飯甑洲', 5, true),
  _SpotDemo(22.3713053, 114.3278067, '大頭洲', 4, true),
  _SpotDemo(22.3310887, 114.3720555, '橫洲', 4, true),
  _SpotDemo(22.2855400, 114.1167311, '小青洲', 4, true),
  _SpotDemo(22.2846322, 114.1130982, '青洲', 4, true),

  // Second verified batch.
  _SpotDemo(22.2094533, 114.1497273, '南丫島', 4, true),
  _SpotDemo(22.2246740, 114.1345839, '鹿洲', 4, true),
  _SpotDemo(22.3761161, 113.8832683, '龍鼓洲', 5, true),
  _SpotDemo(22.4538426, 114.2298514, '馬屎洲', 4, true),
  _SpotDemo(22.3491170, 114.0581104, '馬灣', 4, true),
  _SpotDemo(22.2342199, 114.1856184, '熨波洲', 4, true),
  _SpotDemo(22.3423035, 114.3518656, '南風洲', 5, true),
  _SpotDemo(22.2859216, 114.0443124, '坪洲', 4, true),
  _SpotDemo(22.5455581, 114.4283418, '東平洲', 5, true),
  _SpotDemo(22.3583810, 114.3784988, '破邊洲', 5, true),
  _SpotDemo(22.1757113, 114.2760100, '蒲台群島', 5, true),
  _SpotDemo(22.3455335, 113.8902846, '沙洲', 5, true),
  _SpotDemo(22.1953247, 113.9868986, '石鼓洲', 5, true),
  _SpotDemo(22.1722140, 113.9132037, '索罟群島', 5, true),
  _SpotDemo(22.2610430, 114.0513371, '周公島', 4, true),
  _SpotDemo(22.3400813, 114.0626712, '燈籠洲', 4, true),
  _SpotDemo(22.3444190, 114.0989543, '青衣島', 4, true),
  _SpotDemo(22.4356844, 114.4019300, '和尚洲', 5, true),
  _SpotDemo(22.4485372, 114.3947025, '黃茅洲', 5, true),

  // Remaining verified batch. Auto-accepted only when OSM/Nominatim
  // feature type matched island/islet/rock/reef/locality and stayed within
  // 1.5km of the existing map.gov-derived seed coordinate.
  _SpotDemo(22.4392668, 114.2222517, '丫洲', 4, true),
  _SpotDemo(22.5277135, 114.2108398, '鴉洲', 4, true),
  _SpotDemo(22.2236093, 114.0230818, '北長洲石', 5, true),
  _SpotDemo(22.5495795, 114.2697607, '鴨洲尾白墩排', 5, true),
  _SpotDemo(22.5505375, 114.2674470, '鴨洲白墩排', 5, true),
  _SpotDemo(22.2399354, 114.1545244, '鴨脷洲', 4, true),
  _SpotDemo(22.5524605, 114.2648762, '鴨籮春', 4, true),
  _SpotDemo(22.5530943, 114.2655155, '鴨蛋排', 5, true),
  _SpotDemo(22.5358285, 114.2723331, '鴨兜排', 5, true),
  _SpotDemo(22.3357668, 114.3340652, '匙洲', 4, true),
  _SpotDemo(22.4613720, 114.4202898, '打浪排', 5, true),
  _SpotDemo(22.3364806, 114.3677559, '崩鼻洲', 4, true),
  _SpotDemo(22.4592739, 114.2874203, '崩紗排', 5, true),
  _SpotDemo(22.2147878, 113.9459523, '茶果洲', 4, true),
  _SpotDemo(22.3802759, 114.2955196, '炸魚排', 5, true),
  _SpotDemo(22.4901750, 114.3652851, '杉排', 5, true),
  _SpotDemo(22.3237159, 114.3298323, '沉排', 5, true),
  _SpotDemo(22.3791527, 114.2889098, '枕頭洲', 4, true),
  _SpotDemo(22.5143410, 114.2946646, '執毛洲', 4, true),
  _SpotDemo(22.4716835, 114.3573514, '洲仔角', 4, true),
  _SpotDemo(22.3534064, 114.3506028, '洲仔', 4, true),
  _SpotDemo(22.4636296, 114.2909172, '扯里排', 5, true),
  _SpotDemo(22.3152422, 113.9358616, '赤鱲角', 4, true),
  _SpotDemo(22.2088220, 114.0295672, '長洲', 4, true),
  _SpotDemo(22.3347302, 114.0237523, '長索', 4, true),
  _SpotDemo(22.4130681, 114.4061639, '長咀洲', 4, true),
  _SpotDemo(22.2911769, 114.0690264, '德己利士礁', 5, true),
  _SpotDemo(22.4787701, 114.3312512, '銀洲', 4, true),
  _SpotDemo(22.2761013, 114.3592380, '火燒排', 5, true),
  _SpotDemo(22.5202377, 114.2861033, '虎王洲', 4, true),
  _SpotDemo(22.5334849, 114.2761824, '墳洲', 4, true),
  _SpotDemo(22.2241444, 114.0159729, '蝦鬚排', 5, true),
  _SpotDemo(22.4774837, 114.3534283, '孝子角排', 5, true),
  _SpotDemo(22.2514077, 114.0389871, '喜靈洲', 4, true),
  _SpotDemo(22.4831853, 114.3328234, '蜆排', 5, true),
  _SpotDemo(22.2534634, 114.1909750, '香港島', 4, true),
  _SpotDemo(22.5099218, 114.2907750, '紅排', 5, true),
  _SpotDemo(22.3669170, 114.3245033, '雞洲', 4, true),
  _SpotDemo(22.2057074, 114.2592449, '狗脾洲', 4, true),
  _SpotDemo(22.2845270, 114.0764858, '交椅洲', 4, true),
  _SpotDemo(22.1502000, 114.2128000, '螺洲白排', 5, true),
  _SpotDemo(22.4810872, 114.1553601, '橋頭', 4, true),
  _SpotDemo(22.5311178, 114.2920517, '高排', 5, true),
  _SpotDemo(22.5145449, 114.3005188, '角大排', 5, true),
  _SpotDemo(22.3389386, 114.3751036, '光頭排', 5, true),
  _SpotDemo(22.3164458, 114.1988698, '九龍石', 5, true),
  _SpotDemo(22.4836140, 114.3706343, '弓洲', 4, true),
  _SpotDemo(22.3741580, 114.3013810, '罐杉環', 4, true),
  _SpotDemo(22.2650464, 114.2797167, '觀仔', 4, true),
  _SpotDemo(22.3038292, 114.3167792, '癩痢仔', 4, true),
  _SpotDemo(22.4057873, 114.3877507, '爛頭排', 5, true),
  _SpotDemo(22.3862407, 114.2822923, '垃圾洲', 4, true),
  _SpotDemo(22.2069508, 114.2228023, '羅洲', 4, true),
  _SpotDemo(22.3644273, 114.2996845, '鷀鸕排', 5, true),
  _SpotDemo(22.3630708, 114.3253372, '老虎吊排', 5, true),
  _SpotDemo(22.2087992, 114.0369247, '饅頭排', 5, true),
  _SpotDemo(22.2408139, 114.1432474, '龍山排', 5, true),
  _SpotDemo(22.3066333, 114.3670152, '龍船排', 5, true),
  _SpotDemo(22.4768947, 114.0329586, '甩洲', 4, true),
  _SpotDemo(22.3228632, 114.3272727, '孖仔排', 5, true),
  _SpotDemo(22.2433652, 114.1390773, '火藥洲', 4, true),
  _SpotDemo(22.1990917, 113.9815009, '尾排', 5, true),
  _SpotDemo(22.3713941, 114.3012844, '芒洲仔', 4, true),
  _SpotDemo(22.2258865, 114.2575888, '五分洲', 4, true),
  _SpotDemo(22.3888449, 114.3159205, '牙鷹洲', 4, true),
  _SpotDemo(22.2426614, 114.2807001, '牙鷹排', 5, true),
  _SpotDemo(22.3296433, 114.0587666, '岩口石', 5, true),
  _SpotDemo(22.3221323, 114.3017347, '牛頭排', 5, true),
  _SpotDemo(22.3562651, 113.8746893, '白洲, Tree Island', 4, true),
  _SpotDemo(22.5328314, 114.2884218, '筆架洲', 4, true),
  _SpotDemo(22.3475171, 114.2743543, '白馬咀排', 5, true),
  _SpotDemo(22.3077078, 114.3096715, '白排', 5, true),
  _SpotDemo(22.2162627, 113.8368221, '雞翼角', 4, true),
  _SpotDemo(22.3654743, 113.9897530, '龍珠島', 4, true),
  _SpotDemo(22.3264663, 114.3685127, '扁洲', 4, true),
  _SpotDemo(22.5455581, 114.4283418, '平洲', 4, true),
  _SpotDemo(22.3118819, 114.3186306, '平面洲', 4, true),
  _SpotDemo(22.1757113, 114.2760100, '蒲苔群島', 5, true),
  _SpotDemo(22.5461832, 114.2956369, '蒲魚排', 5, true),
  _SpotDemo(22.3217287, 114.0681188, '半山石', 5, true),
  _SpotDemo(22.3221181, 114.3660044, '尖柱石', 5, true),
  _SpotDemo(22.5515500, 114.2612219, '細鴨洲', 4, true),
  _SpotDemo(22.3115783, 114.3726190, '三排', 5, true),
  _SpotDemo(22.4327292, 114.2719976, '三杯酒', 4, true),
  _SpotDemo(22.5248410, 114.2885613, '沙排', 5, true),
  _SpotDemo(22.2054300, 114.0465791, '深水排', 5, true),
  _SpotDemo(22.5231883, 114.2924684, '筲箕排', 5, true),
  _SpotDemo(22.1734329, 113.9071550, '石洲', 5, true),
  _SpotDemo(22.4663511, 114.4276462, '石牛洲', 5, true),
  _SpotDemo(22.5483028, 114.2626485, '雙排', 5, true),
  _SpotDemo(22.5319501, 114.2273411, '水浸咀排', 5, true),
  _SpotDemo(22.2124015, 113.9901578, '水排', 5, true),
  _SpotDemo(22.2886783, 114.0591200, '小交椅洲', 4, true),
  _SpotDemo(22.5384192, 114.2673990, '小稔洲', 4, true),
  _SpotDemo(22.3763858, 114.2880863, '小鏟洲', 4, true),
  _SpotDemo(22.5174434, 114.3054827, '打蠔排', 5, true),
  _SpotDemo(22.2568111, 114.3502808, '大洲', 4, true),
  _SpotDemo(22.2894183, 114.0328421, '大利', 4, true),
  _SpotDemo(22.5421496, 114.2656150, '大稔洲', 4, true),
  _SpotDemo(22.3120602, 114.3704851, '大排', 5, true),
  _SpotDemo(22.3756440, 114.2899328, '大鏟洲', 4, true),
  _SpotDemo(22.4464492, 114.2578151, '燈洲', 4, true),
  _SpotDemo(22.2244923, 114.1918241, '頭洲', 4, true),
  _SpotDemo(22.2633439, 114.2766259, '鐵蔘洲', 4, true),
  _SpotDemo(22.3259066, 114.3201152, '吊鐘排', 5, true),
  _SpotDemo(22.3415901, 114.3469955, '塘口排', 5, true),
  _SpotDemo(22.2111109, 114.2122597, '劏人排', 5, true),
  _SpotDemo(22.3010525, 114.3199529, '大癩痢', 4, true),
  _SpotDemo(22.2165740, 113.9801195, '咀排', 5, true),
  _SpotDemo(22.3710022, 114.2956963, '斷頭洲', 4, true),
  _SpotDemo(22.3256589, 114.3683260, '棟心洲', 4, true),
  _SpotDemo(22.3312363, 114.3452056, '桅夾排', 5, true),
  _SpotDemo(22.2758968, 114.3602841, '橫排', 5, true),
  _SpotDemo(22.5420063, 114.3116732, '黃泥洲', 4, true),
  _SpotDemo(22.5152413, 114.3133066, '往灣洲', 4, true),
  _SpotDemo(22.3272890, 114.3135948, '往灣排', 5, true),
  _SpotDemo(22.3861123, 114.3166622, '黃宜洲', 4, true),
  _SpotDemo(22.5012597, 114.3044690, '烏洲', 4, true),
  _SpotDemo(22.5260606, 114.2842923, '烏排', 5, true),
  _SpotDemo(22.5182250, 114.2901560, '湖洋洲排', 5, true),
  _SpotDemo(22.3031161, 114.0357318, '烏蠅排', 5, true),
  _SpotDemo(22.5262530, 114.2878304, '印洲', 4, true),
  _SpotDemo(22.3736270, 114.2956651, '游龍角', 4, true),
  _SpotDemo(22.5396292, 114.3072896, '洋洲', 4, true),
  _SpotDemo(22.3802579, 114.2818232, '羊洲', 4, true),
  _SpotDemo(22.2124015, 113.9901578, '二浪排', 5, true),
  _SpotDemo(22.3119420, 114.3717315, '二排', 5, true),
  _SpotDemo(22.4524066, 114.2138917, '鹽田仔', 4, true),
  _SpotDemo(22.3256692, 114.3669638, '圓崗洲', 4, true),
  _SpotDemo(22.3534064, 114.3506028, 'Chau Tsai', 4, true),
  _SpotDemo(22.2782748, 114.2681091, '佛堂洲', 4, true),
  _SpotDemo(22.2845018, 114.1824371, 'Kellett Island', 4, true),
  _SpotDemo(22.2107252, 113.9036353, 'Lam Chau', 4, true),
  _SpotDemo(22.3830335, 113.9755880, 'Mouse Island', 4, true),
  _SpotDemo(22.3888449, 114.3159205, 'Nga Ying Chau', 4, true),
  _SpotDemo(22.3219132, 114.1383171, 'Stonecutters Island', 4, true),
  _SpotDemo(22.5325825, 114.2804494, 'Tsing Chau', 4, true),
  _SpotDemo(22.4564581, 114.2583046, '東頭洲', 4, true),
  _SpotDemo(22.4457681, 114.1785585, '元洲仔', 4, true),
];

const List<_SpotDemo> _developerTestSpots = [
  _SpotDemo(22.3819, 114.1874, '沙田希爾頓中心測試釣點', 1, false),
];

class _RadarGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final maxR = (size.width > size.height ? size.width : size.height) / 2;
    final rp = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.cyanAccent.withValues(alpha: 0.15);
    final bp = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.lightGreenAccent.withValues(alpha: 0.10);
    for (var i = 1; i <= 4; i++) {
      canvas.drawCircle(c, maxR * i / 4, rp);
    }
    for (var a = 0; a < 360; a += 45) {
      final r = a * 0.0174533;
      canvas.drawLine(
          c, Offset(c.dx + maxR * _cos(r), c.dy + maxR * _sin(r)), bp);
    }
  }

  double _cos(double x) {
    x = x % 6.28318;
    double r = 1, t = 1;
    for (int n = 1; n <= 10; n++) {
      t *= -x * x / ((2 * n - 1) * (2 * n));
      r += t;
    }
    return r;
  }

  double _sin(double x) {
    x = x % 6.28318;
    double r = x, t = x;
    for (int n = 1; n <= 10; n++) {
      t *= -x * x / ((2 * n) * (2 * n + 1));
      r += t;
    }
    return r;
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _GameWorldMapShell extends StatelessWidget {
  const _GameWorldMapShell({
    required this.spotCount,
    required this.hasLiveLocation,
    required this.playerLatLng,
    required this.spots,
    required this.terrainDataSource,
    required this.mapBearingDegrees,
    required this.onSpotSelected,
  });

  final int spotCount;
  final bool hasLiveLocation;
  final LatLng playerLatLng;
  final List<_SpotDemo> spots;
  final TerrainDataSource terrainDataSource;
  final double mapBearingDegrees;
  final void Function(_SpotDemo spot) onSpotSelected;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final viewportSize = Size(
              constraints.maxWidth,
              constraints.maxHeight,
            );
            final camera = GameMapCamera(
              center: playerLatLng,
              visibleRadiusMeters: 500,
              bearingDegrees: mapBearingDegrees,
              viewportSize: viewportSize,
            );
            final featureStore = terrainDataSource is GeoTerrainDataSource
                ? GameMapFeatureStore(
                    dataset:
                        (terrainDataSource as GeoTerrainDataSource).dataset,
                  )
                : null;
            final terrainFeatures =
                featureStore?.visibleTerrainFeatures(camera) ??
                    terrainDataSource.visibleVectorFeatures(
                      playerLatLng: playerLatLng,
                      radiusMeters: 900,
                    );
            final terrainTiles = terrainDataSource.buildTiles(
              playerLatLng: playerLatLng,
              rows: 17,
              cols: 13,
            );
            final fishingSpotInputs = [
              for (final spot in spots)
                GameMapFishingSpot(
                  id: '${spot.name}:${spot.lat}:${spot.lng}',
                  name: spot.name,
                  position: LatLng(spot.lat, spot.lng),
                ),
            ];
            final fishingSpots = featureStore?.projectFishingSpots(
                  camera: camera,
                  spots: fishingSpotInputs,
                ) ??
                [
                  for (final spot in fishingSpotInputs)
                    if (camera.isVisible(spot.position))
                      ProjectedFishingSpot(
                        id: spot.id,
                        name: spot.name,
                        position: spot.position,
                        screenPosition: camera.project(spot.position),
                      ),
                ];
            return Stack(
              fit: StackFit.expand,
              children: [
                IgnorePointer(
                  child: GameMapRenderer(
                    camera: camera,
                    terrainTiles: terrainTiles,
                    terrainFeatures: terrainFeatures,
                    fishingSpots: fishingSpots,
                  ),
                ),
                ..._buildProjectedSpotButtons(camera),
              ],
            );
          },
        ),
        IgnorePointer(
          child: CustomPaint(
            painter: _GameWorldAtmospherePainter(
              spotCount: spotCount,
              hasLiveLocation: hasLiveLocation,
            ),
            size: Size.infinite,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildProjectedSpotButtons(GameMapCamera camera) {
    return [
      for (final spot in spots)
        if (camera.isVisible(LatLng(spot.lat, spot.lng)))
          Positioned(
            left: camera.project(LatLng(spot.lat, spot.lng)).dx - 59,
            top: camera.project(LatLng(spot.lat, spot.lng)).dy - 76,
            width: 118,
            height: 106,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => onSpotSelected(spot),
              child: _SpotMarker(spot: spot),
            ),
          ),
    ];
  }
}

class _PanoramaMapButton extends StatelessWidget {
  const _PanoramaMapButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '全景地圖',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Color(0xFFE3F4FF)],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black38,
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.white70,
                blurRadius: 2,
                offset: Offset(-1, -1),
              ),
            ],
          ),
          child: const Icon(Icons.map, color: Color(0xFF126B82), size: 23),
        ),
      ),
    );
  }
}

class _RotateMapButton extends StatelessWidget {
  const _RotateMapButton({
    required this.bearingDegrees,
    required this.onTap,
  });

  final double bearingDegrees;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '旋轉地圖',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF07323B), Color(0xFF126B82)],
            ),
            border: Border.all(
              color: const Color(0xFF8EF7E8).withValues(alpha: 0.85),
              width: 1.4,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black38,
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.white70,
                blurRadius: 2,
                offset: Offset(-1, -1),
              ),
            ],
          ),
          child: Transform.rotate(
            angle: bearingDegrees * math.pi / 180,
            child: Stack(
              alignment: Alignment.center,
              children: const [
                Icon(
                  Icons.sync,
                  color: Color(0x66FFFFFF),
                  size: 29,
                ),
                Icon(
                  Icons.explore,
                  color: Colors.white,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PanoramaMapSheet extends StatelessWidget {
  const _PanoramaMapSheet({
    required this.spots,
    required this.playerLatLng,
    required this.hasLiveLocation,
    required this.playerAccuracyMeters,
    required this.equipped,
    required this.spotDisplayRadiusMeters,
    required this.rarityColor,
    required this.onSpotSelected,
  });

  final List<_SpotDemo> spots;
  final LatLng playerLatLng;
  final bool hasLiveLocation;
  final double? playerAccuracyMeters;
  final Map<String, String> equipped;
  final double spotDisplayRadiusMeters;
  final Color Function(int rarity) rarityColor;
  final void Function(_SpotDemo spot) onSpotSelected;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).padding;
    final mapController = MapController();
    final markers = [
      ...spots.map(
        (spot) => Marker(
          point: LatLng(spot.lat, spot.lng),
          width: 118,
          height: 106,
          alignment: const Alignment(0, -0.58),
          child: GestureDetector(
            onTap: () => onSpotSelected(spot),
            child: _SpotMarker(spot: spot),
          ),
        ),
      ),
      Marker(
        point: playerLatLng,
        width: 60,
        height: 60,
        alignment: Alignment.center,
        child: IgnorePointer(
          child: _PlayerAvatar(
            equipped: equipped,
            isLiveLocation: hasLiveLocation,
          ),
        ),
      ),
    ];

    return Container(
      height: MediaQuery.of(context).size.height,
      decoration: const BoxDecoration(color: Color(0xFF0F2630)),
      child: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: playerLatLng,
              initialZoom: 13,
              minZoom: 11,
              maxZoom: 16.5,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.drag |
                    InteractiveFlag.pinchZoom |
                    InteractiveFlag.doubleTapZoom,
                pinchZoomThreshold: 0.4,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                tileProvider: NetworkTileProvider(silenceExceptions: true),
                evictErrorTileStrategy: EvictErrorTileStrategy.dispose,
                errorTileCallback: (_, __, ___) {},
                userAgentPackageName: 'com.fishergo.app',
              ),
              CircleLayer(
                circles: [
                  if (hasLiveLocation && playerAccuracyMeters != null)
                    CircleMarker(
                      point: playerLatLng,
                      radius: playerAccuracyMeters!,
                      useRadiusInMeter: true,
                      color: Colors.cyanAccent.withValues(alpha: 0.14),
                      borderColor: Colors.cyanAccent.withValues(alpha: 0.7),
                      borderStrokeWidth: 1.2,
                    ),
                  CircleMarker(
                    point: playerLatLng,
                    radius: spotDisplayRadiusMeters,
                    useRadiusInMeter: true,
                    color: Colors.cyanAccent.withValues(alpha: 0.05),
                    borderColor: Colors.cyanAccent.withValues(alpha: 0.35),
                    borderStrokeWidth: 1,
                  ),
                  ...spots.map((spot) => CircleMarker(
                        point: LatLng(spot.lat, spot.lng),
                        radius: 80,
                        useRadiusInMeter: true,
                        color: rarityColor(spot.rarity).withValues(alpha: 0.15),
                        borderColor: rarityColor(spot.rarity),
                        borderStrokeWidth: 1.5,
                      )),
                ],
              ),
              MarkerLayer(markers: markers),
            ],
          ),
          Positioned(
            top: padding.top + 12,
            left: 12,
            right: 12,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.62),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.22),
                      ),
                    ),
                    child: const Icon(Icons.close, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.62),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.16),
                      ),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '全景地圖',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '拖動畫面找釣點，點選圖標查看詳情',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GameWorldAtmospherePainter extends CustomPainter {
  const _GameWorldAtmospherePainter({
    required this.spotCount,
    required this.hasLiveLocation,
  });

  final int spotCount;
  final bool hasLiveLocation;

  @override
  void paint(Canvas canvas, Size size) {
    final depthShade = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF022F3F).withValues(alpha: 0.03),
          Colors.transparent,
          const Color(0xFF021D1F).withValues(alpha: 0.2),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, depthShade);
    _drawPlayerRings(canvas, size);
  }

  void _drawWaterDetail(Canvas canvas, Size size, double horizonY) {
    final islandPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF289D8D).withValues(alpha: 0.38),
          const Color(0xFF81E2B0).withValues(alpha: 0.2),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, horizonY + 70));
    final islands = [
      Rect.fromCenter(
        center: Offset(size.width * 0.18, horizonY + 26),
        width: size.width * 0.34,
        height: 30,
      ),
      Rect.fromCenter(
        center: Offset(size.width * 0.88, horizonY + 8),
        width: size.width * 0.3,
        height: 22,
      ),
    ];
    for (final rect in islands) {
      canvas.drawOval(rect, islandPaint);
    }

    final ripplePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (final spec in [
      (0.1, 0.13, 0.24),
      (0.42, 0.1, 0.18),
      (0.68, 0.17, 0.22),
      (0.76, 0.25, 0.16),
      (0.18, 0.24, 0.15),
    ]) {
      final (x, y, w) = spec;
      final path = Path()
        ..moveTo(size.width * x, size.height * y)
        ..quadraticBezierTo(
          size.width * (x + w * 0.45),
          size.height * (y - 0.015),
          size.width * (x + w),
          size.height * y,
        );
      canvas.drawPath(path, ripplePaint);
    }
  }

  void _drawIsometricTiles(Canvas canvas, Size size) {
    final tilePaints = [
      Paint()..color = const Color(0xFFA7EE8C).withValues(alpha: 0.78),
      Paint()..color = const Color(0xFF84DF81).withValues(alpha: 0.78),
      Paint()..color = const Color(0xFFC5F6A2).withValues(alpha: 0.72),
      Paint()..color = const Color(0xFF58C98C).withValues(alpha: 0.68),
      Paint()..color = const Color(0xFFE3EE8E).withValues(alpha: 0.46),
    ];
    final edgePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final centerX = size.width * 0.5;
    final startY = size.height * 0.31;
    final tileW = size.width * 0.24;
    final tileH = size.height * 0.06;

    for (var row = 0; row < 12; row++) {
      final rowScale = 0.5 + row * 0.067;
      for (var col = -6; col <= 6; col++) {
        final x = centerX +
            (col * tileW * 0.72 * rowScale) +
            ((row.isOdd ? tileW * 0.22 : 0) * rowScale);
        final y = startY + row * tileH * 0.78;
        final w = tileW * rowScale;
        final h = tileH * rowScale;
        final path = Path()
          ..moveTo(x, y - h * 0.5)
          ..lineTo(x + w * 0.5, y)
          ..lineTo(x, y + h * 0.5)
          ..lineTo(x - w * 0.5, y)
          ..close();
        canvas.drawPath(
          path.shift(Offset(0, h * 0.12)),
          Paint()..color = const Color(0xFF0B624E).withValues(alpha: 0.12),
        );
        canvas.drawPath(
          path,
          tilePaints[(row * 2 + col.abs()) % tilePaints.length],
        );
        canvas.drawPath(path, edgePaint);
      }
    }
  }

  void _drawLandmarks(Canvas canvas, Size size, double horizonY) {
    final bridgePaint = Paint()
      ..color = const Color(0xFF2D6F87).withValues(alpha: 0.42)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final deckY = horizonY + 16;
    canvas.drawLine(
      Offset(size.width * 0.64, deckY),
      Offset(size.width * 0.98, deckY - 12),
      bridgePaint,
    );
    for (final x in [0.69, 0.83, 0.94]) {
      canvas.drawLine(
        Offset(size.width * x, deckY + 1),
        Offset(size.width * x, deckY - 34),
        bridgePaint,
      );
    }

    final islandPaint = Paint()
      ..color = const Color(0xFF3B9C83).withValues(alpha: 0.36);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.2, horizonY + 20),
        width: size.width * 0.28,
        height: 22,
      ),
      islandPaint,
    );

    final skylinePaint = Paint()
      ..color = const Color(0xFF176D83).withValues(alpha: 0.2);
    for (final spec in [
      (0.08, 18.0, 26.0),
      (0.13, 12.0, 20.0),
      (0.2, 16.0, 24.0),
      (0.73, 12.0, 18.0),
      (0.8, 20.0, 28.0),
      (0.88, 14.0, 22.0),
    ]) {
      final (x, w, h) = spec;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(size.width * x, horizonY - h + 18, w, h),
          const Radius.circular(2),
        ),
        skylinePaint,
      );
    }
  }

  void _drawWaterChannels(Canvas canvas, Size size) {
    final channelPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF2ABFD7).withValues(alpha: 0.5),
          const Color(0xFF8AF1DC).withValues(alpha: 0.34),
        ],
      ).createShader(
          Rect.fromLTWH(0, size.height * 0.28, size.width, size.height * 0.46))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 38
      ..strokeCap = StrokeCap.round;
    final foamPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final channel = Path()
      ..moveTo(size.width * -0.08, size.height * 0.54)
      ..cubicTo(
        size.width * 0.18,
        size.height * 0.43,
        size.width * 0.42,
        size.height * 0.48,
        size.width * 0.67,
        size.height * 0.36,
      )
      ..quadraticBezierTo(
        size.width * 0.84,
        size.height * 0.29,
        size.width * 1.1,
        size.height * 0.33,
      );
    canvas.drawPath(channel, channelPaint);
    canvas.drawPath(channel, foamPaint);

    final inletPaint = Paint()
      ..color = const Color(0xFF25B8CF).withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 26
      ..strokeCap = StrokeCap.round;
    final inlet = Path()
      ..moveTo(size.width * 1.06, size.height * 0.7)
      ..cubicTo(
        size.width * 0.8,
        size.height * 0.62,
        size.width * 0.68,
        size.height * 0.72,
        size.width * 0.52,
        size.height * 0.82,
      );
    canvas.drawPath(inlet, inletPaint);
  }

  void _drawPerspectiveGrid(Canvas canvas, Size size, Offset vanishing) {
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (var i = 0; i < 8; i++) {
      final t = i / 7;
      final left = Offset(size.width * (0.02 + 0.28 * t), size.height);
      final right = Offset(size.width * (0.98 - 0.28 * t), size.height);
      canvas.drawLine(left, vanishing, gridPaint);
      canvas.drawLine(right, vanishing, gridPaint);
    }

    for (var i = 0; i < 8; i++) {
      final y = size.height * (0.34 + i * 0.085);
      final inset = (y - size.height * 0.34) * 0.22;
      canvas.drawLine(
        Offset(inset, y),
        Offset(size.width - inset, y),
        gridPaint,
      );
    }
  }

  void _drawRoads(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = const Color(0xFFFFE3A2).withValues(alpha: 0.96)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round;
    final roadEdge = Paint()
      ..color = const Color(0xFF2B8D6E).withValues(alpha: 0.78)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 30
      ..strokeCap = StrokeCap.round;
    final roadHighlight = Paint()
      ..color = Colors.white.withValues(alpha: 0.72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final roads = [
      Path()
        ..moveTo(size.width * -0.12, size.height * 0.76)
        ..cubicTo(
          size.width * 0.2,
          size.height * 0.62,
          size.width * 0.52,
          size.height * 0.65,
          size.width * 1.12,
          size.height * 0.52,
        ),
      Path()
        ..moveTo(size.width * 0.1, size.height * 1.05)
        ..cubicTo(
          size.width * 0.22,
          size.height * 0.82,
          size.width * 0.43,
          size.height * 0.66,
          size.width * 0.52,
          size.height * 0.5,
        )
        ..quadraticBezierTo(
          size.width * 0.62,
          size.height * 0.32,
          size.width * 0.82,
          size.height * 0.18,
        ),
      Path()
        ..moveTo(size.width * 0.0, size.height * 0.46)
        ..quadraticBezierTo(
          size.width * 0.3,
          size.height * 0.38,
          size.width * 0.66,
          size.height * 0.42,
        ),
      Path()
        ..moveTo(size.width * 0.92, size.height * 1.04)
        ..cubicTo(
          size.width * 0.76,
          size.height * 0.78,
          size.width * 0.72,
          size.height * 0.56,
          size.width * 0.92,
          size.height * 0.42,
        ),
    ];

    for (final path in roads) {
      canvas.drawPath(path, roadEdge);
      canvas.drawPath(path, roadPaint);
      canvas.drawPath(path, roadHighlight);
    }

    final nodePaint = Paint()
      ..color = const Color(0xFFFDF7C6)
      ..style = PaintingStyle.fill;
    final nodeStroke = Paint()
      ..color = const Color(0xFF0B6170)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    for (final node in [
      Offset(size.width * 0.26, size.height * 0.62),
      Offset(size.width * 0.49, size.height * 0.5),
      Offset(size.width * 0.73, size.height * 0.53),
      Offset(size.width * 0.58, size.height * 0.74),
    ]) {
      canvas.drawCircle(node, 10, nodePaint);
      canvas.drawCircle(node, 12, nodeStroke);
    }
  }

  void _drawMapProps(Canvas canvas, Size size) {
    final treeAnchors = [
      Offset(size.width * 0.18, size.height * 0.48),
      Offset(size.width * 0.3, size.height * 0.56),
      Offset(size.width * 0.76, size.height * 0.48),
      Offset(size.width * 0.68, size.height * 0.68),
      Offset(size.width * 0.23, size.height * 0.72),
      Offset(size.width * 0.84, size.height * 0.62),
      Offset(size.width * 0.12, size.height * 0.82),
      Offset(size.width * 0.9, size.height * 0.76),
      Offset(size.width * 0.38, size.height * 0.78),
      Offset(size.width * 0.62, size.height * 0.44),
    ];
    for (final p in treeAnchors) {
      _drawTree(canvas, p, size.width * 0.022);
    }

    final pierPaint = Paint()
      ..color = const Color(0xFFB98454)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.08, size.height * 0.34),
      Offset(size.width * 0.22, size.height * 0.42),
      pierPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.16, size.height * 0.36),
      Offset(size.width * 0.23, size.height * 0.34),
      pierPaint..strokeWidth = 4,
    );
    canvas.drawLine(
      Offset(size.width * 0.82, size.height * 0.32),
      Offset(size.width * 0.68, size.height * 0.43),
      pierPaint..strokeWidth = 7,
    );
    for (final t in [0.0, 0.32, 0.64, 0.96]) {
      final p = Offset.lerp(
        Offset(size.width * 0.82, size.height * 0.32),
        Offset(size.width * 0.68, size.height * 0.43),
        t,
      )!;
      canvas.drawLine(
        p.translate(-6, 0),
        p.translate(6, 0),
        Paint()
          ..color = const Color(0xFFE4B67B)
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }

    for (final p in [
      Offset(size.width * 0.42, size.height * 0.45),
      Offset(size.width * 0.54, size.height * 0.58),
      Offset(size.width * 0.79, size.height * 0.58),
    ]) {
      _drawLamp(canvas, p, size.width * 0.018);
    }
  }

  void _drawTree(Canvas canvas, Offset base, double scale) {
    final trunkPaint = Paint()..color = const Color(0xFF7A5B35);
    final crownPaint = Paint()..color = const Color(0xFF1FAF62);
    final lightPaint = Paint()..color = const Color(0xFF75E889);
    canvas.drawRect(
      Rect.fromCenter(
        center: base.translate(0, scale * 1.4),
        width: scale * 0.7,
        height: scale * 2.2,
      ),
      trunkPaint,
    );
    canvas.drawCircle(base, scale * 1.65, crownPaint);
    canvas.drawCircle(
        base.translate(-scale * 0.45, -scale * 0.35), scale * 0.65, lightPaint);
  }

  void _drawLamp(Canvas canvas, Offset base, double scale) {
    final pole = Paint()
      ..color = const Color(0xFF0A5D63)
      ..strokeWidth = scale * 0.45
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(base, base.translate(0, -scale * 5), pole);
    canvas.drawCircle(
      base.translate(0, -scale * 5.4),
      scale * 1.1,
      Paint()..color = const Color(0xFFFFF0A6).withValues(alpha: 0.88),
    );
    canvas.drawCircle(
      base.translate(0, -scale * 5.4),
      scale * 2.5,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFE16B).withValues(alpha: 0.3),
            const Color(0xFFFFE16B).withValues(alpha: 0),
          ],
        ).createShader(
          Rect.fromCircle(
              center: base.translate(0, -scale * 5.4), radius: scale * 2.6),
        ),
    );
  }

  void _drawRockyFishingEdges(Canvas canvas, Size size) {
    final rockPaints = [
      Paint()..color = const Color(0xFF6F8A7A),
      Paint()..color = const Color(0xFF9AAB8B),
      Paint()..color = const Color(0xFF526D67),
    ];
    final rocks = [
      Offset(size.width * 0.11, size.height * 0.31),
      Offset(size.width * 0.2, size.height * 0.33),
      Offset(size.width * 0.74, size.height * 0.32),
      Offset(size.width * 0.86, size.height * 0.3),
      Offset(size.width * 0.9, size.height * 0.47),
      Offset(size.width * 0.08, size.height * 0.52),
    ];
    for (var i = 0; i < rocks.length; i++) {
      final p = rocks[i];
      final r = size.width * (0.017 + (i % 3) * 0.006);
      final path = Path()
        ..moveTo(p.dx, p.dy - r)
        ..lineTo(p.dx + r * 1.25, p.dy - r * 0.2)
        ..lineTo(p.dx + r * 0.85, p.dy + r)
        ..lineTo(p.dx - r * 0.8, p.dy + r * 0.75)
        ..lineTo(p.dx - r * 1.2, p.dy - r * 0.2)
        ..close();
      canvas.drawPath(path, rockPaints[i % rockPaints.length]);
    }
  }

  void _drawPlayerRings(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.56);
    final outerRingPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withValues(alpha: hasLiveLocation ? 0.24 : 0.16);
    final innerRingPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withValues(alpha: hasLiveLocation ? 0.62 : 0.38);
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.22),
          Colors.white.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: 150));
    canvas.drawCircle(center, 150, glowPaint);
    canvas.drawCircle(center, 130, outerRingPaint);
    canvas.drawCircle(center, 72, innerRingPaint);
  }

  @override
  bool shouldRepaint(covariant _GameWorldAtmospherePainter oldDelegate) =>
      oldDelegate.spotCount != spotCount ||
      oldDelegate.hasLiveLocation != hasLiveLocation;
}

class _PlayerAvatar extends StatelessWidget {
  const _PlayerAvatar({required this.equipped, required this.isLiveLocation});

  final Map<String, String> equipped;
  final bool isLiveLocation;

  @override
  Widget build(BuildContext context) {
    final accent = isLiveLocation ? Colors.cyanAccent : Colors.orangeAccent;
    return Stack(alignment: Alignment.center, children: [
      Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              accent.withValues(alpha: 0.8),
              Colors.blueAccent.withValues(alpha: 0.2),
              Colors.transparent,
            ],
          ),
        ),
      ),
      Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: accent, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.5),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(
          isLiveLocation ? Icons.my_location : Icons.location_searching,
          color: isLiveLocation ? Colors.cyan : Colors.deepOrange,
          size: 24,
        ),
      ),
    ]);
  }
}

class _SpotMarker extends StatelessWidget {
  const _SpotMarker({required this.spot});

  final _SpotDemo spot;

  Color get c {
    switch (spot.rarity) {
      case 1:
        return Colors.green;
      case 2:
        return Colors.blue;
      case 3:
        return Colors.purple;
      case 4:
        return Colors.orange;
      case 5:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: c,
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: [
            BoxShadow(
                color: c.withValues(alpha: 0.6),
                blurRadius: 14,
                spreadRadius: 2),
          ],
        ),
        child: const Icon(Icons.set_meal, color: Colors.white, size: 22),
      ),
      const SizedBox(height: 4),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          spot.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ),
      if (spot.isNew)
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.green,
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text('NEW',
              style: TextStyle(color: Colors.white, fontSize: 8)),
        ),
    ]);
  }
}

class _LocateButton extends StatelessWidget {
  const _LocateButton({
    required this.isLocating,
    required this.hasLiveLocation,
    required this.accuracyMeters,
    required this.onTap,
  });

  final bool isLocating;
  final bool hasLiveLocation;
  final double? accuracyMeters;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = hasLiveLocation ? Colors.cyanAccent : Colors.orangeAccent;
    final label = isLocating
        ? '定位中'
        : hasLiveLocation
            ? 'GPS ${accuracyMeters?.round() ?? '?'}m'
            : '重新定位';

    return GestureDetector(
      onTap: isLocating ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.68),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withValues(alpha: 0.75)),
          boxShadow: const [
            BoxShadow(
              color: Colors.black38,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(
            isLocating
                ? Icons.sync
                : hasLiveLocation
                    ? Icons.my_location
                    : Icons.location_searching,
            color: accent,
            size: 18,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ]),
      ),
    );
  }
}

class _TopStatusBar extends StatelessWidget {
  const _TopStatusBar({
    required this.spotCount,
    required this.autoEnabled,
    required this.onToggleAuto,
    required this.leadingLabel,
    required this.subtitleLabel,
  });

  final int spotCount;
  final bool autoEnabled;
  final VoidCallback onToggleAuto;
  final String leadingLabel;
  final String subtitleLabel;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFFFFFF), Color(0xFFE3F4FF)],
                  ),
                ),
                child: const Icon(
                  Icons.directions_boat_filled,
                  color: Color(0xFF126B82),
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      leadingLabel,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '$subtitleLabel · 附近 $spotCount 個釣點',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(width: 8),
      GestureDetector(
        onTap: onToggleAuto,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: autoEnabled ? Colors.green : Colors.black54,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.navigation,
                  color: autoEnabled ? Colors.white : Colors.white54, size: 16),
              const SizedBox(width: 4),
              Text(
                '雷達',
                style: TextStyle(
                    color: autoEnabled ? Colors.white : Colors.white54,
                    fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    ]);
  }
}

class _SideButtons extends StatelessWidget {
  const _SideButtons({required this.onOpenScreen, required this.isAdmin});

  final void Function(GameScreen) onOpenScreen;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      // account/login - guests return here
      _HudBtn(
        icon: Icons.account_circle,
        color: Colors.blue,
        label: '帐戶',
        onTap: () => onOpenScreen(GameScreen.profile),
      ),
      const SizedBox(height: 8),
      _HudBtn(
        icon: Icons.menu_book,
        color: Colors.amber,
        label: '圖鑑',
        onTap: () => onOpenScreen(GameScreen.encyclopedia),
      ),
      const SizedBox(height: 8),
      _HudBtn(
        icon: Icons.inventory_2,
        color: Colors.orange,
        label: '背包',
        onTap: () => onOpenScreen(GameScreen.profile),
      ),
      const SizedBox(height: 8),
      _HudBtn(
        icon: Icons.add_a_photo,
        color: Colors.lightGreenAccent,
        label: '上魚獲',
        onTap: () => onOpenScreen(GameScreen.catchLog),
      ),
      const SizedBox(height: 8),
      _HudBtn(
        icon: Icons.emoji_events,
        color: Colors.purple,
        label: '排行',
        onTap: () => onOpenScreen(GameScreen.leaderboard),
      ),
      if (isAdmin) ...[
        const SizedBox(height: 8),
        _HudBtn(
          icon: Icons.admin_panel_settings,
          color: Colors.redAccent,
          label: 'Admin',
          onTap: () => onOpenScreen(GameScreen.admin),
        ),
      ],
    ]);
  }
}

class _HudBtn extends StatelessWidget {
  const _HudBtn({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.black54,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 9)),
      ]),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.hasCurrent,
    required this.pendingCount,
    required this.baitSummary,
    required this.canFish,
    required this.onAddCheckpoint,
    required this.onFishNearby,
  });

  final bool hasCurrent;
  final int pendingCount;
  final String baitSummary;
  final bool canFish;
  final VoidCallback onAddCheckpoint;
  final VoidCallback? onFishNearby;

  @override
  Widget build(BuildContext context) {
    final fishingAction = canFish ? onFishNearby : onAddCheckpoint;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(children: [
        Expanded(
          child: Row(
            children: [
              const Icon(Icons.pest_control,
                  color: Colors.greenAccent, size: 20),
              const SizedBox(width: 6),
              Text(baitSummary,
                  style: const TextStyle(color: Colors.white, fontSize: 13)),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: onAddCheckpoint,
          icon: const Icon(Icons.add_location, size: 18),
          label: const Text('定點'),
          style: TextButton.styleFrom(foregroundColor: Colors.cyanAccent),
        ),
        const SizedBox(width: 6),
        ElevatedButton.icon(
          onPressed: fishingAction,
          icon: const Icon(Icons.phishing, size: 18),
          label: Text(canFish ? '開釣' : '買餌'),
          style: ElevatedButton.styleFrom(
            backgroundColor:
                fishingAction == null ? Colors.white24 : Colors.cyan,
            foregroundColor:
                fishingAction == null ? Colors.white54 : Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ]),
    );
  }
}

class _SpotDetailCard extends StatelessWidget {
  const _SpotDetailCard({
    required this.spot,
    required this.onClose,
    required this.distanceMeters,
    required this.unlockRadiusMeters,
    required this.canStartFishing,
    required this.onStartFishing,
  });

  final _SpotDemo spot;
  final VoidCallback onClose;
  final double distanceMeters;
  final double unlockRadiusMeters;
  final bool canStartFishing;
  final VoidCallback? onStartFishing;

  Color get c {
    switch (spot.rarity) {
      case 1:
        return Colors.green;
      case 2:
        return Colors.blue;
      case 3:
        return Colors.purple;
      case 4:
        return Colors.orange;
      case 5:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String get label {
    switch (spot.rarity) {
      case 1:
        return '普通';
      case 2:
        return '罕見';
      case 3:
        return '稀有';
      case 4:
        return '史詩';
      case 5:
        return '傳說';
      default:
        return '';
    }
  }

  String get biomeLabel => FishingBiomeRules.labelFor(spot.biome);

  String get backdropAsset => FishingBiomeRules.backdropAssetFor(
        spotName: spot.name,
        biome: spot.biome,
      );

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1e2d3d),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(children: [
              Image.asset(backdropAsset,
                  height: 110, width: double.infinity, fit: BoxFit.cover),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        const Color(0xFF1e2d3d).withValues(alpha: 0.9)
                      ],
                    ),
                  ),
                ),
              ),
            ]),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.location_on, color: c, size: 24),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(spot.name,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                        ),
                        IconButton(
                            icon:
                                const Icon(Icons.close, color: Colors.white54),
                            onPressed: onClose),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                              color: c, borderRadius: BorderRadius.circular(8)),
                          child: Text(label,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.white)),
                        ),
                        if (spot.isNew) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(8)),
                            child: const Text('NEW',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.white)),
                          ),
                        ],
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: c.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Text(
                            biomeLabel,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      canStartFishing
                          ? '已到達釣點，可以開釣'
                          : '距離 ${distanceMeters.round()}m，到達 ${unlockRadiusMeters.round()}m 內才能開釣',
                      style: TextStyle(
                        color: canStartFishing
                            ? Colors.greenAccent
                            : Colors.orangeAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: onStartFishing,
                        icon: const Icon(Icons.phishing),
                        label: Text(canStartFishing ? '開釣' : '未到達釣點'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              canStartFishing ? Colors.cyan : Colors.white24,
                          foregroundColor:
                              canStartFishing ? Colors.black : Colors.white54,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ]),
            ),
          ]),
    );
  }
}
