import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/location/location_access_service.dart';
import '../../../core/permissions/android_permission_gate.dart';
import '../../../core/telemetry/app_telemetry.dart';
import '../../fish/data/sample_fish_species_data_source.dart';
import '../../fish/domain/fish_collection_copy.dart';
import '../../fish/domain/fish_collection_service.dart';
import '../../fish/domain/fish_collection_status.dart';
import '../../fish/domain/fish_species.dart';
import '../../profile/data/profile_wallet_service.dart';
import '../../profile/domain/game_shop_item.dart';
import '../../profile/presentation/profile_screen.dart';
import '../data/catch_log_local_data_source.dart';
import '../data/catch_history_service.dart';
import '../data/catch_photo_url_resolver.dart';
import '../data/fish_recognition_service.dart';
import '../data/real_catch_claim_service.dart';
import '../data/catch_sync_service.dart';
import '../data/offline_sync_coordinator.dart';
import '../data/hk_fishing_spots_geocoded_seed.dart';
import '../data/virtual_fishing_session_service.dart';
import '../domain/catch_log_entry.dart';
import 'catch_log_semantics.dart';

class CatchLogScreen extends StatefulWidget {
  const CatchLogScreen({
    super.key,
    this.localDataSource,
    this.syncService,
    this.connectivityChanges,
    this.mapOnly = false,
    this.gameHome = false,
    this.onOpenScreen,
  });

  final CatchLogLocalDataSource? localDataSource;
  final CatchSyncService? syncService;
  final Stream<List<ConnectivityResult>>? connectivityChanges;
  final bool mapOnly;
  final bool gameHome;
  final ValueChanged<int>? onOpenScreen;

  @override
  State<CatchLogScreen> createState() => _CatchLogScreenState();
}

class _CatchLogScreenState extends State<CatchLogScreen> {
  static const _settingsBoxName = 'catch_settings';

  /// Hong Kong territory center — keeps the overworld map framed over the full city.
  static const _hkTerritoryCenter = LatLng(22.3600, 114.1350);
  static final _hkTerritoryBounds = LatLngBounds(
    const LatLng(22.165038897, 113.836755853),
    const LatLng(22.554402221, 114.433370247),
  );

  final _lengthController = TextEditingController();
  final _weightController = TextEditingController();
  final _notesController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final MapController _mapController = MapController();

  late final CatchLogLocalDataSource _localDataSource;
  late final CatchSyncService _syncService;
  late final CatchHistoryService _historyService;
  late final OfflineSyncCoordinator _offlineSyncCoordinator;
  late final List<FishSpecies> _species;
  late final _SpotCommunityService _spotCommunityService;
  List<CatchLogEntry> _pending = const [];
  List<CatchHistoryItem> _remoteHistory = const [];
  bool? _isOnline;

  String? _selectedSpeciesId;
  DateTime _caughtAt = DateTime.now();
  XFile? _photoXFile; // Cross-platform image from picker
  Uint8List? _photoBytes; // Preloaded bytes for display
  double? _latitude;
  double? _longitude;
  double? _locationAccuracyMeters;
  final List<CatchCheckpoint> _checkpoints = [];
  final Set<String> _autoCheckedSpotIds = <String>{};
  final Map<String, List<String>> _otherSpeciesCache = <String, List<String>>{};
  Map<String, int> _consumables = const {};
  Map<String, String> _equippedItems = const {};
  StreamSubscription<Position>? _positionSubscription;
  var _autoCheckpointEnabled = true;
  var _saving = false;
  var _loadingOtherSpecies = false;
  double _mapZoom = 10.5;

  /// AI fish recognition
  FishRecognitionService? _recognitionService;
  var _isRecognizing = false;
  String? _aiSuggestionText;
  int _mapDetailTier = 0;

  @override
  void initState() {
    super.initState();
    _localDataSource = widget.localDataSource ?? CatchLogLocalDataSource();
    final supabaseClient =
        SupabaseConfig.isConfigured ? Supabase.instance.client : null;
    _syncService = widget.syncService ??
        CatchSyncService(
          remote: supabaseClient == null
              ? const _UnavailableCatchRemoteDataSource()
              : SupabaseCatchRemoteDataSource(supabaseClient),
        );
    _historyService = CatchHistoryService(
      dataSource: supabaseClient == null
          ? const _UnavailableCatchHistoryDataSource()
          : SupabaseCatchHistoryDataSource(supabaseClient),
      photoUrlResolver: supabaseClient == null
          ? null
          : SupabaseCatchPhotoUrlResolver(supabaseClient),
    );
    _offlineSyncCoordinator = OfflineSyncCoordinator(
      connectivityChanges:
          widget.connectivityChanges ?? Connectivity().onConnectivityChanged,
      onOnlineChanged: _handleConnectivityStatus,
      syncPending: _syncPending,
    )..start();
    _species = const SampleFishSpeciesDataSource().loadSpecies();
    _spotCommunityService = _SpotCommunityService(
      client: supabaseClient,
      speciesById: {
        for (final fish in _species) fish.id: fish.displayLocalName,
      },
    );
    if (_species.isNotEmpty) {
      _selectedSpeciesId = _species.first.id;
    }
    _loadPending();
    _loadRemoteHistory();
    _loadConsumables();
    _loadGeofenceSetting();
    _recognitionService = FishRecognitionService();
  }

  Future<void> _loadPending() async {
    final entries = await _localDataSource
        .loadPending()
        .catchError((_) => <CatchLogEntry>[]);
    if (!mounted) return;
    setState(() => _pending = entries);
  }

  void _handleConnectivityStatus(bool isOnline) {
    if (!mounted || _isOnline == isOnline) return;
    setState(() => _isOnline = isOnline);
  }

  Future<void> _loadRemoteHistory() async {
    if (!SupabaseConfig.isConfigured) return;
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final history = await _historyService.load(userId: userId);
      if (!mounted) return;
      setState(() => _remoteHistory = history);
    } catch (_) {
      // Offline/cloud read failures leave the local catch queue usable.
    }
  }

  Future<void> _loadConsumables() async {
    final consumables = await ProfileWalletService.getConsumables();
    final equipped = await ProfileWalletService.getEquippedItems();
    if (!mounted) return;
    setState(() {
      _consumables = consumables;
      _equippedItems = equipped;
    });
  }

  Future<void> _loadGeofenceSetting() async {
    final box = await Hive.openBox(_settingsBoxName);
    final enabled = box.get('auto_geofence_enabled');
    if (!mounted) return;
    if (enabled is bool) {
      setState(() => _autoCheckpointEnabled = enabled);
    }
  }

  Future<void> _setAutoCheckpointEnabled(bool value) async {
    setState(() => _autoCheckpointEnabled = value);
    final box = await Hive.openBox(_settingsBoxName);
    await box.put('auto_geofence_enabled', value);
    if (value) {
      _showSnack('已開啟自動打卡（較耗電）');
    } else {
      _showSnack('已關閉自動打卡（省電模式）');
    }
  }

  @override
  void dispose() {
    unawaited(_offlineSyncCoordinator.dispose());
    _positionSubscription?.cancel();
    _lengthController.dispose();
    _weightController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.gameHome) {
      return Scaffold(
        body: SafeArea(
          child: _buildCheckpointSection(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.mapOnly ? '釣點雷達地圖' : '魚獲記錄（離線佇列）'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: widget.mapOnly
            ? [
                _buildCheckpointSection(),
                const SizedBox(height: 16),
                _buildPendingList(),
                _buildRemoteHistory(),
              ]
            : [
                _buildInfoBanner(),
                const SizedBox(height: 12),
                _buildForm(context),
                const SizedBox(height: 16),
                _buildPendingList(),
                _buildRemoteHistory(),
              ],
      ),
    );
  }

  Widget _buildInfoBanner() {
    final connectivityLabel = _isOnline == null
        ? '連線檢查中'
        : _isOnline!
            ? '已連線'
            : '離線';
    final connectivityIcon = _isOnline == false
        ? Icons.cloud_off_outlined
        : Icons.cloud_done_outlined;
    final connectivityColor = _isOnline == false ? Colors.orange : Colors.teal;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(connectivityIcon, size: 18, color: connectivityColor),
                const SizedBox(width: 6),
                Text(
                  connectivityLabel,
                  style: TextStyle(
                    color: connectivityColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '可先匿名試玩：魚獲會先儲存在本機。建立 FisherGO 帳戶後，可備份魚獲、換機保留紀錄及參加排行榜。\n待備份：${_pending.length} 筆',
            ),
            const SizedBox(height: 10),
            FilledButton.tonalIcon(
              onPressed: _pending.isEmpty ? null : _syncPending,
              icon: const Icon(Icons.cloud_upload),
              label: const Text('備份魚獲'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Photo section - tap to pick
          Semantics(
            button: true,
            label: '選擇魚獲相片',
            child: InkWell(
              onTap: _pickPhoto,
              child: Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: _photoBytes != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          _photoBytes!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _buildPhotoPlaceholder(),
                        ),
                      )
                    : _buildPhotoPlaceholder(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: _pickPhoto,
                icon: const Icon(Icons.photo_library),
                label: const Text('選擇相片'),
              ),
              FilledButton.tonalIcon(
                onPressed: _isRecognizing ? null : _recognizeFish,
                icon: _isRecognizing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.psychology),
                label: Text(_isRecognizing ? 'AI 辨識中...' : 'AI 認魚'),
              ),
              FilledButton.tonalIcon(
                onPressed: _pickLocation,
                icon: const Icon(Icons.my_location),
                label: const Text('定位'),
              ),
              FilledButton.tonalIcon(
                onPressed: _pickDateTime,
                icon: const Icon(Icons.schedule),
                label: const Text('時間'),
              ),
            ],
          ),
          if (_aiSuggestionText != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome,
                      color: Colors.blue.shade700, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _aiSuggestionText!,
                      style:
                          TextStyle(color: Colors.blue.shade800, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          // Auto location display
          Row(
            children: [
              const Icon(Icons.schedule, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                '時間：${_caughtAt.year}-${_caughtAt.month.toString().padLeft(2, '0')}-${_caughtAt.day.toString().padLeft(2, '0')} '
                '${_caughtAt.hour.toString().padLeft(2, '0')}:${_caughtAt.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_latitude != null && _longitude != null)
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.green),
                const SizedBox(width: 4),
                Text(
                  '位置：${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          const SizedBox(height: 16),
          // Species dropdown
          DropdownButtonFormField<String>(
            initialValue: _selectedSpeciesId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: '魚種',
              prefixIcon: Icon(Icons.set_meal),
            ),
            items: _species
                .map((fish) => DropdownMenuItem(
                      value: fish.id,
                      child: Text(
                        fish.displayLocalName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ))
                .toList(growable: false),
            onChanged: (value) => setState(() => _selectedSpeciesId = value),
          ),
          const SizedBox(height: 16),
          _buildCheckpointSection(),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save),
              label: Text(_saving ? '儲存中...' : '加入待同步佇列'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoPlaceholder() {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_a_photo, size: 48, color: Colors.grey),
        SizedBox(height: 8),
        Text('點擊拍照或選擇相片', style: TextStyle(color: Colors.grey)),
      ],
    );
  }

  Widget _buildPendingList() {
    if (_pending.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('暫時未有待同步魚獲。'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: _pending
              .map(
                (entry) => ListTile(
                  leading: const Icon(Icons.pending_actions),
                  title: Text(entry.speciesName),
                  subtitle: Text(
                    '${_formatDateTime(entry.caughtAt)} · ${entry.syncStatus.name} · CP ${entry.checkpoints.length}（自動 ${_autoCheckpointCount(entry.checkpoints)}）',
                  ),
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
  }

  Widget _buildRemoteHistory() {
    if (!SupabaseConfig.isConfigured || _remoteHistory.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '雲端魚獲',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            ..._remoteHistory.map(
              (item) => ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                leading: _buildRemoteCatchThumbnail(item),
                title: Text(item.record.speciesName),
                subtitle: Text(_formatDateTime(item.record.caughtAt)),
                trailing: item.record.isRealCatchProof
                    ? const Icon(
                        Icons.verified,
                        color: Colors.teal,
                        semanticLabel: '真實釣獲相片已驗證',
                      )
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRemoteCatchThumbnail(CatchHistoryItem item) {
    final url = item.photoUrl;
    if (url == null) {
      return const CircleAvatar(
        child: Icon(Icons.set_meal),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const SizedBox(
          width: 48,
          height: 48,
          child: ColoredBox(
            color: Color(0xFFE0F2F1),
            child: Icon(Icons.broken_image_outlined),
          ),
        ),
      ),
    );
  }

  Widget _buildCheckpointSection() {
    final hasCurrent = _latitude != null && _longitude != null;
    final center = _hkTerritoryCenter;

    final renderedSpots = _renderSpotsByDetailTier(_mapDetailTier);

    final markers = <Marker>[
      ...renderedSpots.map(
        (rendered) => Marker(
          point: LatLng(rendered.latitude, rendered.longitude),
          width: 44,
          height: 44,
          child: Semantics(
            button: true,
            label: catchLogSpotSemanticsLabel(rendered.spots.length),
            child: GestureDetector(
              onTap: () {
                if (rendered.spots.length == 1) {
                  _showSpotBottomSheet(rendered.spots.first);
                  return;
                }
                _showClusterBottomSheet(rendered);
              },
              child: _FishingSpotMapMarker(
                count: rendered.spots.length,
              ),
            ),
          ),
        ),
      ),
      if (widget.gameHome || hasCurrent)
        Marker(
          point: LatLng(
            _latitude ?? _hkTerritoryCenter.latitude,
            _longitude ?? _hkTerritoryCenter.longitude,
          ),
          width: widget.gameHome ? 66 : 54,
          height: widget.gameHome ? 66 : 54,
          child: _PlayerAvatarMapMarker(equipped: _equippedItems),
        ),
      ..._checkpoints.map(
        (cp) => Marker(
          point: LatLng(cp.latitude, cp.longitude),
          width: 34,
          height: 34,
          child: const Icon(Icons.location_on, color: Colors.red, size: 24),
        ),
      ),
    ];

    if (widget.gameHome) {
      return _buildGameHomeRadar(
        center: center,
        hasCurrent: hasCurrent,
        renderedSpots: renderedSpots,
        markers: markers,
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.map),
                const SizedBox(width: 8),
                Text(
                  '釣點雷達地圖',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Chip(
                    label: Text(
                        '顯示 ${renderedSpots.length}/${_hkFishingSpots.length}')),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('進入範圍自動打點'),
              subtitle: const Text('陸地 50m、海島 250m'),
              value: _autoCheckpointEnabled,
              onChanged: _setAutoCheckpointEnabled,
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: widget.gameHome
                    ? math.max(300, MediaQuery.of(context).size.height - 260)
                    : 220,
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: center,
                        initialZoom: hasCurrent ? 15 : 11,
                        onPositionChanged: (position, _) =>
                            _handleMapPositionChanged(position),
                        onTap: (_, point) =>
                            _addCheckpoint(point.latitude, point.longitude),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          tileProvider:
                              NetworkTileProvider(silenceExceptions: true),
                          evictErrorTileStrategy:
                              EvictErrorTileStrategy.dispose,
                          errorTileCallback: (_, __, ___) {},
                          userAgentPackageName: 'com.fishergo.app',
                        ),
                        OverlayImageLayer(
                          overlayImages: [
                            OverlayImage(
                              imageProvider: const AssetImage(
                                  'assets/maps/hk_overworld_overlay.png'),
                              bounds: _hkTerritoryBounds,
                              opacity: 0.54,
                              gaplessPlayback: true,
                            ),
                          ],
                        ),
                        CircleLayer(
                          circles: _hkFishingSpots
                              .map(
                                (spot) => CircleMarker(
                                  point: LatLng(spot.latitude, spot.longitude),
                                  radius: spot.radiusMeters,
                                  useRadiusInMeter: true,
                                  color: spot.isIsland
                                      ? Colors.cyan.withValues(alpha: 0.20)
                                      : Colors.lightGreenAccent
                                          .withValues(alpha: 0.18),
                                  borderColor: spot.isIsland
                                      ? Colors.cyanAccent
                                      : Colors.lightGreenAccent,
                                  borderStrokeWidth: 2,
                                ),
                              )
                              .toList(growable: false),
                        ),
                        if (_checkpoints.length >= 2)
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: _checkpoints
                                    .map((e) => LatLng(e.latitude, e.longitude))
                                    .toList(growable: false),
                                color:
                                    Colors.cyanAccent.withValues(alpha: 0.85),
                                strokeWidth: 4,
                              ),
                            ],
                          ),
                        MarkerLayer(markers: markers),
                      ],
                    ),
                    IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment.center,
                            radius: 0.85,
                            colors: [
                              Colors.transparent,
                              Colors.white.withValues(alpha: 0.02),
                              Colors.cyan.withValues(alpha: 0.06),
                            ],
                          ),
                        ),
                      ),
                    ),
                    IgnorePointer(
                      child: CustomPaint(
                        painter: _RadarGridPainter(),
                        size: Size.infinite,
                      ),
                    ),
                    Positioned(
                      left: 10,
                      top: 10,
                      child: _MapHudPill(
                        icon: Icons.radar,
                        label: 'FISH RADAR',
                        color: Colors.cyanAccent,
                      ),
                    ),
                    Positioned(
                      right: 10,
                      top: 10,
                      child: _MapHudPill(
                        icon: Icons.location_searching,
                        label: hasCurrent ? 'GPS ON' : 'HK DEMO',
                        color: hasCurrent
                            ? Colors.lightGreenAccent
                            : Colors.amberAccent,
                      ),
                    ),
                    if (widget.gameHome)
                      Positioned(
                        left: 10,
                        right: 10,
                        bottom: 12,
                        child: _buildGameHudButtons(),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '目前路徑：${_checkpoints.length} 點（自動 ${_autoCheckpointCount(_checkpoints)}，釣點關聯 ${_spotLinkedCheckpointCount(_checkpoints)}）',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: hasCurrent ? _addCurrentLocationCheckpoint : null,
                  icon: const Icon(Icons.add_location_alt),
                  label: const Text('加目前位置'),
                ),
                FilledButton.tonalIcon(
                  onPressed: _checkpoints.isEmpty
                      ? null
                      : () {
                          setState(() => _checkpoints.removeLast());
                        },
                  icon: const Icon(Icons.undo),
                  label: const Text('刪最後一點'),
                ),
                FilledButton.tonalIcon(
                  onPressed: _checkpoints.isEmpty
                      ? null
                      : () {
                          setState(_checkpoints.clear);
                        },
                  icon: const Icon(Icons.clear_all),
                  label: const Text('清空路徑'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameHomeRadar({
    required LatLng center,
    required bool hasCurrent,
    required List<_RenderedSpot> renderedSpots,
    required List<Marker> markers,
  }) {
    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;
    return Stack(
      children: [
        Positioned.fill(
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: hasCurrent ? 15 : 11,
              onPositionChanged: (position, _) =>
                  _handleMapPositionChanged(position),
              onTap: (_, point) =>
                  _addCheckpoint(point.latitude, point.longitude),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                tileProvider: NetworkTileProvider(silenceExceptions: true),
                evictErrorTileStrategy: EvictErrorTileStrategy.dispose,
                errorTileCallback: (_, __, ___) {},
                userAgentPackageName: 'com.fishergo.app',
              ),
              OverlayImageLayer(
                overlayImages: [
                  OverlayImage(
                    imageProvider: const AssetImage(
                        'assets/maps/hk_overworld_overlay.png'),
                    bounds: _hkTerritoryBounds,
                    opacity: 0.72,
                    gaplessPlayback: true,
                  ),
                ],
              ),
              CircleLayer(
                circles: _hkFishingSpots
                    .map(
                      (spot) => CircleMarker(
                        point: LatLng(spot.latitude, spot.longitude),
                        radius: spot.radiusMeters,
                        useRadiusInMeter: true,
                        color: spot.isIsland
                            ? Colors.cyan.withValues(alpha: 0.15)
                            : Colors.lightGreenAccent.withValues(alpha: 0.14),
                        borderColor: spot.isIsland
                            ? Colors.cyanAccent.withValues(alpha: 0.82)
                            : Colors.greenAccent.withValues(alpha: 0.82),
                        borderStrokeWidth: 1.6,
                      ),
                    )
                    .toList(growable: false),
              ),
              if (_checkpoints.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _checkpoints
                          .map((e) => LatLng(e.latitude, e.longitude))
                          .toList(growable: false),
                      color: Colors.blueAccent.withValues(alpha: 0.76),
                      strokeWidth: 4,
                    ),
                  ],
                ),
              MarkerLayer(markers: markers),
            ],
          ),
        ),
        IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.20),
                  Colors.transparent,
                  Colors.lightBlue.shade900.withValues(alpha: 0.18),
                ],
              ),
            ),
          ),
        ),
        IgnorePointer(
          child: CustomPaint(
            painter: _RadarGridPainter(),
            size: Size(width, height),
          ),
        ),
        Positioned(
          left: 14,
          top: 12,
          right: 14,
          child: _GameTopStatusBar(
            spotsShown: renderedSpots.length,
            spotsTotal: _hkFishingSpots.length,
            checkpoints: _checkpoints.length,
            autoEnabled: _autoCheckpointEnabled,
            onToggleAuto: () =>
                _setAutoCheckpointEnabled(!_autoCheckpointEnabled),
          ),
        ),
        Positioned(
          right: 12,
          top: 94,
          child: Column(
            children: [
              _GameSideHudButton(
                icon: Icons.menu_book,
                label: '圖鑑',
                onTap: () => widget.onOpenScreen?.call(1),
              ),
              const SizedBox(height: 10),
              _GameSideHudButton(
                icon: Icons.camera_alt,
                label: '魚獲',
                onTap: () => widget.onOpenScreen?.call(2),
              ),
              const SizedBox(height: 10),
              _GameSideHudButton(
                icon: Icons.storefront,
                label: '商店',
                onTap: () => widget.onOpenScreen?.call(4),
              ),
              const SizedBox(height: 10),
              _GameSideHudButton(
                icon: Icons.emoji_events,
                label: '排行',
                onTap: () => widget.onOpenScreen?.call(3),
              ),
              const SizedBox(height: 10),
              _GameSideHudButton(
                icon: Icons.person,
                label: '角色',
                onTap: () => widget.onOpenScreen?.call(4),
              ),
            ],
          ),
        ),
        Positioned(
          left: 14,
          right: 14,
          bottom: 18,
          child: _GameBottomCommandBar(
            hasCurrent: hasCurrent,
            pendingCount: _pending.length,
            baitSummary:
                '普通 ${_consumables['basic_bait'] ?? 0}｜碼頭 ${_consumables['harbor_lure'] ?? 0}｜離島 ${_consumables['island_lure'] ?? 0}',
            onAddCheckpoint: hasCurrent ? _addCurrentLocationCheckpoint : null,
            onFishNearby: _openNearestFishingSpot,
          ),
        ),
      ],
    );
  }

  void _openNearestFishingSpot() {
    final originLat = _latitude ?? _hkTerritoryCenter.latitude;
    final originLng = _longitude ?? _hkTerritoryCenter.longitude;
    _FishingSpot? nearest;
    var bestDistance = double.infinity;
    for (final spot in _hkFishingSpots) {
      final distance = Geolocator.distanceBetween(
        originLat,
        originLng,
        spot.latitude,
        spot.longitude,
      );
      if (distance < bestDistance) {
        bestDistance = distance;
        nearest = spot;
      }
    }
    final spot = nearest;
    if (spot == null) return;
    _showSpotBottomSheet(spot);
  }

  Widget _buildGameHudButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _GameHudButton(
          icon: Icons.menu_book,
          label: '圖鑑',
          onTap: () => widget.onOpenScreen?.call(1),
        ),
        _GameHudButton(
          icon: Icons.camera_alt,
          label: '魚獲',
          onTap: () => widget.onOpenScreen?.call(2),
        ),
        _GameHudButton(
          icon: Icons.storefront,
          label: '商店',
          onTap: () => widget.onOpenScreen?.call(4),
        ),
        _GameHudButton(
          icon: Icons.emoji_events,
          label: '排行',
          onTap: () => widget.onOpenScreen?.call(3),
        ),
        _GameHudButton(
          icon: Icons.person,
          label: '角色',
          onTap: () => widget.onOpenScreen?.call(4),
        ),
      ],
    );
  }

  Future<void> _startLocationTracking() async {
    final access = await _ensureLocationAccess();
    if (access != LocationAccessState.ready) return;

    await _positionSubscription?.cancel();
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 20,
      ),
    ).listen((position) {
      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _locationAccuracyMeters = _normaliseAccuracy(position.accuracy);
      });
      unawaited(_autoCheckpointByGeofence());
    });
  }

  Future<LocationAccessState> _ensureLocationAccess() {
    return AndroidPermissionGate.run(
      () => const LocationAccessService().ensureReady(),
    );
  }

  String _locationAccessMessage(LocationAccessState access) {
    return switch (access) {
      LocationAccessState.serviceDisabled => '請先開啟手機定位服務。',
      LocationAccessState.permissionDenied => '未授權位置權限。',
      LocationAccessState.permissionDeniedForever => '定位權限已永久拒絕，請到系統設定重新開啟。',
      LocationAccessState.ready => '',
    };
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _caughtAt,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date == null || !mounted) return;
    if (!context.mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_caughtAt),
    );
    if (time == null || !mounted) return;

    setState(() {
      _caughtAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _pickPhoto() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null || !mounted) return;
      final bytes = await image.readAsBytes();
      setState(() {
        _photoXFile = image;
        _photoBytes = bytes;
      });
    } catch (_) {
      _showSnack('此平台暫時無法選擇相片，先純文字記錄。');
    }
  }

  Future<void> _pickLocation() async {
    try {
      final access = await _ensureLocationAccess();
      if (access != LocationAccessState.ready) {
        _showSnack(_locationAccessMessage(access));
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _locationAccuracyMeters = _normaliseAccuracy(position.accuracy);
      });
      await _startLocationTracking();
      unawaited(_autoCheckpointByGeofence());
    } catch (_) {
      _showSnack('未能取得定位，請稍後再試。');
    }
  }

  Future<bool> _refreshLocationForFishing() async {
    if (!SupabaseConfig.isConfigured) return true;

    final access = await _ensureLocationAccess();
    if (access != LocationAccessState.ready) {
      if (mounted) _showSnack(_locationAccessMessage(access));
      return false;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      if (!mounted) return false;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _locationAccuracyMeters = _normaliseAccuracy(position.accuracy);
      });
      await _startLocationTracking();
      return _locationAccuracyMeters != null;
    } catch (_) {
      if (mounted) _showSnack('未能取得有效 GPS，釣魚挑戰需要在釣點附近進行。');
      return false;
    }
  }

  double? _normaliseAccuracy(double accuracy) {
    if (!accuracy.isFinite || accuracy < 0 || accuracy > 250) return null;
    return accuracy;
  }

  Future<void> _recognizeFish() async {
    if (_photoXFile == null) {
      _showSnack('請先選擇相片');
      return;
    }

    setState(() {
      _isRecognizing = true;
      _aiSuggestionText = null;
    });

    try {
      final result = await _recognitionService!.recognize(_photoXFile!);
      if (!mounted) return;
      setState(() {
        _isRecognizing = false;
        if (result.isSuccess && result.species != null) {
          _selectedSpeciesId = result.species!.id;
          final conf = ((result.confidence ?? 0) * 100).toInt();
          _aiSuggestionText =
              '🤖 AI 認為：${result.species!.displayLocalName}（$conf% 置信度）';
        } else {
          _aiSuggestionText = '⚠️ AI 辨識失敗：${result.errorMessage}';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isRecognizing = false;
        _aiSuggestionText = '⚠️ 錯誤：$e';
      });
    }
  }

  Future<void> _addCurrentLocationCheckpoint() async {
    if (_latitude == null || _longitude == null) return;
    await _addCheckpoint(_latitude!, _longitude!, triggerType: 'manual');
  }

  Future<void> _addCheckpoint(
    double lat,
    double lng, {
    String? spotId,
    String? spotName,
    String triggerType = 'manual',
  }) async {
    setState(() {
      _checkpoints.add(
        CatchCheckpoint(
          latitude: lat,
          longitude: lng,
          recordedAt: DateTime.now(),
          spotId: spotId,
          spotName: spotName,
          triggerType: triggerType,
        ),
      );
    });

    final reward = triggerType == 'geofence' ? 2 : 5;
    final reason = triggerType == 'geofence' ? 'Geofence 自動打卡' : '手動地圖打卡';
    await ProfileWalletService.addCoins(
      reward,
      reason: reason,
      rewardKind: 'checkpoint',
      claimKey:
          'checkpoint:$triggerType:${DateTime.now().toUtc().microsecondsSinceEpoch}',
    );
  }

  Future<void> _autoCheckpointByGeofence() async {
    if (!_autoCheckpointEnabled || _latitude == null || _longitude == null) {
      return;
    }

    for (final spot in _hkFishingSpots) {
      final distance = Geolocator.distanceBetween(
        _latitude!,
        _longitude!,
        spot.latitude,
        spot.longitude,
      );
      final within = distance <= spot.radiusMeters;
      if (within && !_autoCheckedSpotIds.contains(spot.id)) {
        _autoCheckedSpotIds.add(spot.id);
        _addCheckpoint(
          _latitude!,
          _longitude!,
          spotId: spot.id,
          spotName: spot.name,
          triggerType: 'geofence',
        );
        _showSnack('已進入 ${spot.name} 範圍，自動打點 +1');
      }
      if (!within && _autoCheckedSpotIds.contains(spot.id)) {
        _autoCheckedSpotIds.remove(spot.id);
      }
    }
  }

  List<String> _myCaughtSpeciesAtSpot(_FishingSpot spot) {
    final result = <String>{};
    for (final entry in _pending) {
      if (entry.latitude == null || entry.longitude == null) continue;
      final d = Geolocator.distanceBetween(
        entry.latitude!,
        entry.longitude!,
        spot.latitude,
        spot.longitude,
      );
      if (d <= spot.radiusMeters) {
        result.add(entry.speciesName);
      }
    }
    return result.toList()..sort();
  }

  int _detailTierForZoom(double zoom) {
    if (zoom >= 13.0) return 2;
    if (zoom >= 11.0) return 1;
    return 0;
  }

  void _handleMapPositionChanged(MapCamera position) {
    final zoom = position.zoom;
    final nextTier = _detailTierForZoom(zoom);
    if (!mounted) return;
    if ((zoom - _mapZoom).abs() > 0.01 || nextTier != _mapDetailTier) {
      setState(() {
        _mapZoom = zoom;
        _mapDetailTier = nextTier;
      });
    }
  }

  List<_RenderedSpot> _renderSpotsByDetailTier(int tier) {
    if (tier >= 2) {
      return _hkFishingSpots
          .map(
            (spot) => _RenderedSpot(
              spots: [spot],
              latitude: spot.latitude,
              longitude: spot.longitude,
            ),
          )
          .toList(growable: false);
    }

    final cellSize = tier == 1 ? 0.03 : 0.06;
    final buckets = <String, List<_FishingSpot>>{};

    for (final spot in _hkFishingSpots) {
      final latKey = (spot.latitude / cellSize).floor();
      final lonKey = (spot.longitude / cellSize).floor();
      final key = '$latKey:$lonKey';
      buckets.putIfAbsent(key, () => <_FishingSpot>[]).add(spot);
    }

    return buckets.values.map((spots) {
      final avgLat =
          spots.map((s) => s.latitude).reduce((a, b) => a + b) / spots.length;
      final avgLon =
          spots.map((s) => s.longitude).reduce((a, b) => a + b) / spots.length;
      return _RenderedSpot(spots: spots, latitude: avgLat, longitude: avgLon);
    }).toList(growable: false);
  }

  void _showClusterBottomSheet(_RenderedSpot rendered) {
    final spots = rendered.spots.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('此區域 ${spots.length} 個釣點',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: spots.length,
                  itemBuilder: (context, index) {
                    final spot = spots[index];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(spot.name),
                      subtitle: Text(
                          '${spot.category} · ${spot.radiusMeters.toStringAsFixed(0)}m'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).pop();
                        _showSpotBottomSheet(spot);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<List<String>> _loadOtherSpeciesForSpot(_FishingSpot spot) async {
    final cached = _otherSpeciesCache[spot.id];
    if (cached != null) return cached;

    final species = await _spotCommunityService.fetchOtherPlayersSpecies(
      centerLat: spot.latitude,
      centerLng: spot.longitude,
      radiusMeters: spot.radiusMeters,
      days: 30,
    );
    _otherSpeciesCache[spot.id] = species;
    return species;
  }

  Future<void> _showSpotBottomSheet(_FishingSpot spot) async {
    final mySpecies = _myCaughtSpeciesAtSpot(spot);
    var otherSpecies = _otherSpeciesCache[spot.id] ?? spot.otherPlayersSpecies;

    if (otherSpecies.isEmpty && !_loadingOtherSpecies) {
      setState(() => _loadingOtherSpecies = true);
      try {
        otherSpecies = await _loadOtherSpeciesForSpot(spot);
      } finally {
        if (mounted) setState(() => _loadingOtherSpecies = false);
      }
    }

    if (!mounted) return;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(spot.name, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(
                  '${spot.category} · 半徑 ${spot.radiusMeters.toStringAsFixed(0)}m'),
              const SizedBox(height: 12),
              Text('你曾釣到', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(mySpecies.isEmpty ? '暫無紀錄' : mySpecies.join('、')),
              const SizedBox(height: 12),
              Text('其他玩家曾釣到（30日）',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              if (_loadingOtherSpecies)
                const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Text(otherSpecies.isEmpty ? '暫無紀錄' : otherSpecies.join('、')),
              const SizedBox(height: 12),
              Text('虛擬釣魚', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(
                '普通魚餌 ${_consumables['basic_bait'] ?? 0}｜碼頭誘餌 ${_consumables['harbor_lure'] ?? 0}｜離島誘餌 ${_consumables['island_lure'] ?? 0}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  _virtualFishAtSpot(spot);
                },
                icon: const Icon(Icons.catching_pokemon),
                label: const Text('進入釣魚挑戰'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _virtualFishAtSpot(_FishingSpot spot) async {
    final lureId = _selectLureForSpot(spot);
    if (lureId == null) {
      _showSnack('魚餌不足。請到商城購買魚餌或誘餌。');
      return;
    }
    if (!await _refreshLocationForFishing()) return;

    final fish = _rollFishForSpot(spot, lureId);
    VirtualFishingSession? serverSession;
    try {
      serverSession = await VirtualFishingSessionService.start(
        spotId: spot.id,
        lureId: lureId,
        fishId: fish.id,
        latitude: _latitude,
        longitude: _longitude,
        accuracyMeters: _locationAccuracyMeters,
      );
    } catch (_) {
      if (!mounted) return;
      _showSnack('伺服器未能建立釣魚挑戰，請稍後再試。');
      return;
    }
    if (SupabaseConfig.isConfigured && serverSession == null) {
      _showSnack('釣魚挑戰需要最新版本及位置驗證，暫未發放獎勵。');
      return;
    }
    if (!mounted) return;
    unawaited(
      AppTelemetry.instance.record(
        TelemetryEventName.minigameStarted,
        fields: {'source': 'catch_log'},
      ),
    );
    final result = await showDialog<_FishingMinigameResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _FishingMinigameDialog(
        spotName: spot.name,
        fishName: fish.displayLocalName,
        fishImageAsset: fishGameArtworkAssetPath(fish.imageUrl),
        lureName: gameShopItemById[lureId]?.name ?? lureId,
        bonus: _FishingEquipmentBonus.fromEquipped(_equippedItems),
        serverSession: serverSession,
      ),
    );
    if (!mounted) return;
    if (result == null) return;
    var success = result.localSuccess;
    if (serverSession != null) {
      VirtualFishingResolution? resolution;
      try {
        resolution = await VirtualFishingSessionService.resolve(
          sessionId: serverSession.sessionId,
          pullElapsedMs: result.pullElapsedMs,
        );
      } catch (_) {
        if (!mounted) return;
        _showSnack('釣魚挑戰未能由伺服器確認，未發放獎勵。');
        return;
      }
      if (!mounted) return;
      if (resolution == null) {
        _showSnack('釣魚挑戰未能由伺服器確認，未發放獎勵。');
        return;
      }
      success = resolution.success;
    }
    unawaited(
      AppTelemetry.instance.record(
        TelemetryEventName.minigameCompleted,
        fields: {
          'source': 'catch_log',
          'outcome': success ? 'success' : 'failure',
        },
      ),
    );

    final consumed = await ProfileWalletService.consumeConsumable(
      lureId,
      reason: '釣點挑戰：${spot.name}',
    );
    if (!consumed) {
      _showSnack('魚餌不足。請到商城購買魚餌或誘餌。');
      return;
    }

    await _loadConsumables();
    if (!success) {
      _showSnack('魚跑掉了。已消耗 ${gameShopItemById[lureId]?.name ?? lureId}。');
      return;
    }

    final bonus = _FishingEquipmentBonus.fromEquipped(_equippedItems);
    final reward = 8 + bonus.rewardBonus;
    final updatedCoins = await ProfileWalletService.addCoins(
      reward,
      reason: '虛擬釣獲：${fish.displayLocalName}（裝備+$bonus.rewardBonus）',
      rewardKind: 'virtual_catch',
      claimKey: serverSession == null
          ? 'virtual-catch:${fish.id}:${DateTime.now().toUtc().microsecondsSinceEpoch}'
          : 'virtual-catch-session:${serverSession.sessionId}',
      fishId: fish.id,
      gameplaySessionId: serverSession?.sessionId,
    );
    if (updatedCoins < 0) {
      _showSnack('釣魚獎勵未能確認，圖鑑不會解鎖。');
      return;
    }
    await FishCollectionService.markGameCaught(fish.id);

    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('釣到了！'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                height: 180,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      'assets/minigame/scene_bobber_enhanced.webp',
                      fit: BoxFit.cover,
                    ),
                    if (fishGameArtworkAssetPath(fish.imageUrl) != null)
                      Center(
                        child: Image.asset(
                          fishGameArtworkAssetPath(fish.imageUrl)!,
                          width: 150,
                          height: 150,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(fish.displayLocalName,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('釣點：${spot.name}'),
            Text('使用：${gameShopItemById[lureId]?.name ?? lureId}'),
            const SizedBox(height: 8),
            Text(FishDiscoveryCopy.detailHint(FishDiscoveryStatus.gameCaught)),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('好'),
          ),
        ],
      ),
    );
  }

  String? _selectLureForSpot(_FishingSpot spot) {
    if (spot.isIsland && (_consumables['island_lure'] ?? 0) > 0) {
      return 'island_lure';
    }
    if (!spot.isIsland && (_consumables['harbor_lure'] ?? 0) > 0) {
      return 'harbor_lure';
    }
    if ((_consumables['basic_bait'] ?? 0) > 0) {
      return 'basic_bait';
    }
    return null;
  }

  FishSpecies _rollFishForSpot(_FishingSpot spot, String lureId) {
    final random =
        math.Random(DateTime.now().millisecondsSinceEpoch ^ spot.id.hashCode);
    final candidates = _species.where((fish) {
      if (lureId == 'island_lure') return fish.rarityRank >= 2;
      if (lureId == 'harbor_lure') return fish.rarityRank <= 4;
      return fish.rarityRank <= 3;
    }).toList(growable: false);
    final pool = candidates.isEmpty ? _species : candidates;
    final totalWeight = pool.fold<int>(0, (sum, fish) {
      final rarityBias =
          lureId == 'island_lure' ? fish.rarityRank : (6 - fish.rarityRank);
      return sum + rarityBias.clamp(1, 6);
    });
    var roll = random.nextInt(totalWeight);
    for (final fish in pool) {
      final rarityBias =
          lureId == 'island_lure' ? fish.rarityRank : (6 - fish.rarityRank);
      roll -= rarityBias.clamp(1, 6);
      if (roll < 0) return fish;
    }
    return pool.first;
  }

  Future<void> _syncPending() async {
    if (!mounted || _pending.isEmpty) return;

    setState(() => _saving = true);
    try {
      final summary = await _syncService.sync(_pending);
      if (summary.skipped > 0) {
        _showSnack('建立或登入 FisherGO 帳戶後，才可備份魚獲。你的魚獲仍保存在本機。');
        return;
      }

      final failedEntries = _pending
          .where((entry) => summary.failedIds.contains(entry.id))
          .map(
            (entry) => CatchLogEntry(
              id: entry.id,
              speciesId: entry.speciesId,
              speciesName: entry.speciesName,
              caughtAt: entry.caughtAt,
              lengthCm: entry.lengthCm,
              weightKg: entry.weightKg,
              notes: entry.notes,
              photoPath: entry.photoPath,
              latitude: entry.latitude,
              longitude: entry.longitude,
              checkpoints: entry.checkpoints,
              syncStatus: CatchSyncStatus.failed,
              isRealCatchProof: entry.isRealCatchProof,
              recognitionConfidence: entry.recognitionConfidence,
              recognizedSpeciesId: entry.recognizedSpeciesId,
              verifiedAt: entry.verifiedAt,
            ),
          )
          .toList(growable: false);

      await _localDataSource.savePending(failedEntries);
      await _loadPending();
      await _loadRemoteHistory();
      _showSnack('同步完成：成功 ${summary.synced}，失敗 ${summary.failed}');
    } catch (_) {
      // Connectivity can return before the authenticated API is usable.
      // Keep the local queue and let the next reconnect/manual retry try again.
      _showSnack('同步暫時失敗，魚獲會保留在本機。');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _save() async {
    if (_selectedSpeciesId == null || !_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _saving = true);
    try {
      final fish = _species.firstWhere((item) => item.id == _selectedSpeciesId);
      final photoPath = _photoXFile?.path;
      if (photoPath == null || photoPath.trim().isEmpty) {
        _showSnack('請先上載魚獲相片，才可記錄真實釣獲。');
        return;
      }

      final service = RealCatchClaimService(localDataSource: _localDataSource);
      await service.claim(
        speciesId: fish.id,
        speciesName: fish.displayLocalName,
        caughtAt: _caughtAt,
        lengthCm: _toDoubleOrNull(_lengthController.text),
        weightKg: _toDoubleOrNull(_weightController.text),
        notes: _emptyToNull(_notesController.text),
        photoPath: photoPath,
        latitude: _latitude,
        longitude: _longitude,
        checkpoints: List<CatchCheckpoint>.unmodifiable(_checkpoints),
      );
      await _loadPending();
      // Auto-sync if Supabase is configured
      if (SupabaseConfig.isConfigured) {
        final summary = await _syncService.sync(_pending);
        if (summary.skipped == 0 && summary.synced > 0) {
          // Drop entries that synced; keep only the failed ones so the
          // "待同步" queue reflects what's actually still un-synced.
          final remaining = _pending
              .where((entry) => summary.failedIds.contains(entry.id))
              .map(
                (entry) => CatchLogEntry(
                  id: entry.id,
                  speciesId: entry.speciesId,
                  speciesName: entry.speciesName,
                  caughtAt: entry.caughtAt,
                  lengthCm: entry.lengthCm,
                  weightKg: entry.weightKg,
                  notes: entry.notes,
                  photoPath: entry.photoPath,
                  latitude: entry.latitude,
                  longitude: entry.longitude,
                  checkpoints: entry.checkpoints,
                  syncStatus: CatchSyncStatus.failed,
                  isRealCatchProof: entry.isRealCatchProof,
                  recognitionConfidence: entry.recognitionConfidence,
                  recognizedSpeciesId: entry.recognizedSpeciesId,
                  verifiedAt: entry.verifiedAt,
                ),
              )
              .toList(growable: false);
          await _localDataSource.savePending(remaining);
          await _loadPending();
        }
        await _loadRemoteHistory();
      }
      final rewardBalance = await ProfileWalletService.addCoins(
        20,
        reason: '新增魚獲記錄',
        rewardKind: 'real_catch',
        claimKey:
            'real-catch:${fish.id}:${_caughtAt.toUtc().microsecondsSinceEpoch}',
        fishId: fish.id,
      );
      late final String rewardMessage;
      if (rewardBalance >= 0) {
        rewardMessage = '已加入待同步，圖鑑已標記為真實釣獲（+20 金幣）';
      } else {
        rewardMessage = '已加入待同步，圖鑑已標記為真實釣獲；獎勵待伺服器確認。';
      }

      _lengthController.clear();
      _weightController.clear();
      _notesController.clear();
      if (mounted) {
        setState(() {
          _photoXFile = null;
          _photoBytes = null;
          _latitude = null;
          _longitude = null;
          _checkpoints.clear();
        });
      }

      _showSnack(rewardMessage);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _formatDateTime(DateTime value) {
    final mm = value.month.toString().padLeft(2, '0');
    final dd = value.day.toString().padLeft(2, '0');
    final hh = value.hour.toString().padLeft(2, '0');
    final min = value.minute.toString().padLeft(2, '0');
    return '${value.year}-$mm-$dd $hh:$min';
  }

  double? _toDoubleOrNull(String input) {
    final text = input.trim();
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  String? _emptyToNull(String input) {
    final text = input.trim();
    return text.isEmpty ? null : text;
  }

  int _autoCheckpointCount(List<CatchCheckpoint> checkpoints) {
    return checkpoints.where((cp) => cp.triggerType == 'geofence').length;
  }

  int _spotLinkedCheckpointCount(List<CatchCheckpoint> checkpoints) {
    return checkpoints.where((cp) => (cp.spotId ?? '').isNotEmpty).length;
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _UnavailableCatchRemoteDataSource implements CatchRemoteDataSource {
  const _UnavailableCatchRemoteDataSource();

  @override
  Future<void> uploadCatch({
    required String userId,
    required CatchLogEntry entry,
  }) async {
    throw StateError('Supabase is not configured');
  }
}

class _UnavailableCatchHistoryDataSource implements CatchHistoryDataSource {
  const _UnavailableCatchHistoryDataSource();

  @override
  Future<List<RemoteCatchRecord>> fetchOwnCatches({
    required String userId,
  }) async {
    return const [];
  }
}

class _FishingEquipmentBonus {
  const _FishingEquipmentBonus({
    required this.successStart,
    required this.successEnd,
    required this.speedMultiplier,
    required this.rewardBonus,
    required this.summary,
  });

  final double successStart;
  final double successEnd;
  final double speedMultiplier;
  final int rewardBonus;
  final String summary;

  factory _FishingEquipmentBonus.fromEquipped(Map<String, String> equipped) {
    int tier(String slot) {
      final id = equipped[slot] ?? '';
      final suffix = RegExp(r'_(\d+)$').firstMatch(id)?.group(1);
      return int.tryParse(suffix ?? '')?.clamp(1, 6) ?? 0;
    }

    final rod = tier('rod');
    final hat = tier('hat');
    final mask = tier('mask');
    final shirt = tier('shirt');
    final pants = tier('pants');
    final box = tier('tackle_box');
    final shoes = tier('shoes');
    final widen =
        (rod * 0.015) + (shirt * 0.01) + (mask * 0.008) + (pants * 0.006);
    final start = (0.42 - widen).clamp(0.22, 0.48).toDouble();
    final end = (0.62 + widen).clamp(0.56, 0.80).toDouble();
    final speed = (1.0 - (hat * 0.025)).clamp(0.78, 1.0).toDouble();
    final reward = (box * 2) + shoes;
    final parts = <String>[
      if (rod > 0) '魚竿放寬判定',
      if (hat > 0) '帽子減慢指針',
      if (mask > 0 || shirt > 0 || pants > 0) '服裝增加容錯',
      if (reward > 0) '釣獲+$reward 金幣',
    ];
    return _FishingEquipmentBonus(
      successStart: start,
      successEnd: end,
      speedMultiplier: speed,
      rewardBonus: reward,
      summary: parts.isEmpty ? '沒有裝備加成' : parts.join('｜'),
    );
  }
}

class _FishingMinigameResult {
  const _FishingMinigameResult({
    required this.localSuccess,
    required this.pullElapsedMs,
  });

  final bool localSuccess;
  final int pullElapsedMs;
}

class _FishingMinigameDialog extends StatefulWidget {
  const _FishingMinigameDialog({
    required this.spotName,
    required this.fishName,
    required this.fishImageAsset,
    required this.lureName,
    required this.bonus,
    this.serverSession,
  });

  final String spotName;
  final String fishName;
  final String? fishImageAsset;
  final String lureName;
  final _FishingEquipmentBonus bonus;
  final VirtualFishingSession? serverSession;

  @override
  State<_FishingMinigameDialog> createState() => _FishingMinigameDialogState();
}

class _FishingMinigameDialogState extends State<_FishingMinigameDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _biteTimer;
  Timer? _biteHapticTimer;
  final _pullClock = Stopwatch();
  bool _resolved = false;
  bool? _success;
  bool _biteReady = false;
  int _pullElapsedMs = 0;
  String _resultMessage = '';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration:
          Duration(milliseconds: (1350 / widget.bonus.speedMultiplier).round()),
    )..repeat(reverse: true);
    _pullClock.start();
    _biteTimer = Timer(
      Duration(milliseconds: widget.serverSession?.biteDelayMs ?? 1600),
      _startBite,
    );
  }

  void _startBite() {
    if (!mounted || _resolved) return;
    _controller
      ..stop()
      ..value = 0
      ..repeat(reverse: true);
    setState(() => _biteReady = true);
    HapticFeedback.mediumImpact();
    _biteHapticTimer = Timer.periodic(const Duration(milliseconds: 180), (_) {
      if (mounted && !_resolved && _biteReady) {
        HapticFeedback.selectionClick();
      }
    });
  }

  @override
  void dispose() {
    _biteTimer?.cancel();
    _biteHapticTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _pullRod() {
    if (_resolved) return;
    _pullElapsedMs = _pullClock.elapsedMilliseconds;
    if (!_biteReady) {
      _controller.stop();
      _biteTimer?.cancel();
      setState(() {
        _resolved = true;
        _success = false;
        _resultMessage = '太早抽竿，魚仲未食餌！';
      });
      HapticFeedback.lightImpact();
      return;
    }
    final value = _controller.value;
    final success =
        value >= widget.bonus.successStart && value <= widget.bonus.successEnd;
    _controller.stop();
    _biteHapticTimer?.cancel();
    setState(() {
      _resolved = true;
      _success = success;
      _resultMessage = success ? '時機完美！成功上鉤。' : '慢了一步，魚跑掉了。';
    });
    HapticFeedback.heavyImpact();
  }

  void _finish() {
    Navigator.of(context).pop(
      _FishingMinigameResult(
        localSuccess: _success ?? false,
        pullElapsedMs: _pullElapsedMs,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusMessage = _resolved
        ? _resultMessage
        : _biteReady
            ? '浮標急震，立即按「抽竿」！'
            : '等待魚食餌，浮標郁動後才可以抽竿。';
    final actionLabel = _resolved
        ? '完成'
        : _biteReady
            ? '抽竿，浮標急震，立即抽竿'
            : '抽竿，等待魚食餌';
    return AlertDialog(
      title: const Text('釣魚挑戰'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => SizedBox(
              height: 200,
              width: double.infinity,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      'assets/minigame/scene_bobber_enhanced.webp',
                      fit: BoxFit.cover,
                    ),
                    if (_resolved &&
                        _success == true &&
                        widget.fishImageAsset != null)
                      Center(
                        child: Image.asset(
                          widget.fishImageAsset!,
                          width: 150,
                          height: 150,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    CustomPaint(
                      painter: _FishingScenePainter(
                        pointerValue: _controller.value,
                        resolved: _resolved,
                        success: _success,
                        biteReady: _biteReady,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text('釣點：${widget.spotName}'),
          Text('目標：${widget.fishName}'),
          Text('使用：${widget.lureName}'),
          Text('裝備加成：${widget.bonus.summary}'),
          const SizedBox(height: 16),
          Semantics(
            liveRegion: true,
            label: statusMessage,
            child: Text(
              statusMessage,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: _resolved
                    ? (_success == true
                        ? Colors.green.shade700
                        : Colors.red.shade700)
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (!_biteReady && !_resolved)
            const SizedBox(
              height: 52,
              child: Center(child: Text('等待魚食餌…')),
            )
          else
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return SizedBox(
                  height: 52,
                  child: CustomPaint(
                    painter: _FishingTimingPainter(
                      pointerValue: _controller.value,
                      resolved: _resolved,
                      success: _success,
                      successStart: widget.bonus.successStart,
                      successEnd: widget.bonus.successEnd,
                    ),
                    child: const SizedBox.expand(),
                  ),
                );
              },
            ),
          const SizedBox(height: 8),
          Row(
            children: const [
              Icon(Icons.info_outline, size: 16),
              SizedBox(width: 6),
              Expanded(
                child: Text('成功會解鎖全彩圖示；真實相片確認後會加上魚鈎認證。'),
              ),
            ],
          ),
        ],
      ),
      actions: [
        if (!_resolved)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
        Semantics(
          excludeSemantics: true,
          button: true,
          label: actionLabel,
          child: FilledButton.icon(
            onPressed: _resolved ? _finish : _pullRod,
            icon: Icon(_resolved
                ? (_success == true ? Icons.check_circle : Icons.close)
                : Icons.sports_martial_arts),
            label: Text(_resolved ? '完成' : '抽竿'),
          ),
        ),
      ],
    );
  }
}

class _FishingScenePainter extends CustomPainter {
  const _FishingScenePainter({
    required this.pointerValue,
    required this.resolved,
    required this.success,
    required this.biteReady,
  });

  final double pointerValue;
  final bool resolved;
  final bool? success;
  final bool biteReady;

  @override
  void paint(Canvas canvas, Size size) {
    final waterTop = size.height * 0.48;
    final bobberX = size.width * 0.32;
    final bobberY = waterTop +
        22 +
        (biteReady
            ? math.sin(pointerValue * math.pi * 10) * 16
            : math.sin(pointerValue * math.pi * 2) * 3);

    final ripplePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = Colors.white.withValues(alpha: 0.58);
    for (var i = 0; i < 3; i++) {
      final radius = 18 + i * 15 + math.sin(pointerValue * math.pi * 2) * 3;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(bobberX, bobberY + 3),
          width: radius * 1.7,
          height: radius * 0.55,
        ),
        ripplePaint..color = Colors.white.withValues(alpha: 0.46 - i * 0.10),
      );
    }
    canvas.drawLine(
        Offset(size.width * 0.12, 8),
        Offset(bobberX, bobberY),
        Paint()
          ..color = Colors.black54
          ..strokeWidth = 2);
    canvas.drawCircle(
        Offset(bobberX, bobberY), 10, Paint()..color = Colors.redAccent);
    canvas.drawCircle(Offset(bobberX, bobberY - 4), 10,
        Paint()..color = Colors.white.withValues(alpha: 0.9));

    final fishColor = resolved
        ? (success == true ? Colors.amberAccent : Colors.blueGrey.shade300)
        : Colors.orange.withValues(alpha: 0.72);
    final fishCenter = Offset(size.width * 0.68, waterTop + 52);
    canvas.drawOval(Rect.fromCenter(center: fishCenter, width: 56, height: 24),
        Paint()..color = fishColor);
    final tail = ui.Path()
      ..moveTo(fishCenter.dx + 28, fishCenter.dy)
      ..lineTo(fishCenter.dx + 46, fishCenter.dy - 14)
      ..lineTo(fishCenter.dx + 46, fishCenter.dy + 14)
      ..close();
    canvas.drawPath(tail, Paint()..color = fishColor);

    if (resolved && success == true) {
      final splash = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.white.withValues(alpha: 0.75);
      canvas.drawCircle(Offset(bobberX, bobberY), 22, splash);
      canvas.drawCircle(
          Offset(bobberX, bobberY), 34, splash..strokeWidth = 1.5);
    }
  }

  @override
  bool shouldRepaint(covariant _FishingScenePainter oldDelegate) {
    return oldDelegate.pointerValue != pointerValue ||
        oldDelegate.resolved != resolved ||
        oldDelegate.success != success ||
        oldDelegate.biteReady != biteReady;
  }
}

class _FishingTimingPainter extends CustomPainter {
  const _FishingTimingPainter({
    required this.pointerValue,
    required this.resolved,
    required this.success,
    required this.successStart,
    required this.successEnd,
  });

  final double pointerValue;
  final bool resolved;
  final bool? success;
  final double successStart;
  final double successEnd;

  @override
  void paint(Canvas canvas, Size size) {
    final track = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 16, size.width, 18),
      const Radius.circular(12),
    );
    final bg = Paint()..color = Colors.grey.shade200;
    canvas.drawRRect(track, bg);

    final successRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * successStart,
        16,
        size.width * (successEnd - successStart),
        18,
      ),
      const Radius.circular(12),
    );
    canvas.drawRRect(
      successRect,
      Paint()..color = Colors.greenAccent.shade200,
    );

    final x = pointerValue.clamp(0.0, 1.0) * size.width;
    final pointerPaint = Paint()
      ..color = resolved
          ? (success == true ? Colors.green.shade700 : Colors.red.shade700)
          : Colors.orangeAccent;
    final path = ui.Path()
      ..moveTo(x, 4)
      ..lineTo(x - 9, 16)
      ..lineTo(x + 9, 16)
      ..close();
    canvas.drawPath(path, pointerPaint);
    canvas.drawLine(
      Offset(x, 14),
      Offset(x, 40),
      pointerPaint..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant _FishingTimingPainter oldDelegate) {
    return oldDelegate.pointerValue != pointerValue ||
        oldDelegate.resolved != resolved ||
        oldDelegate.success != success ||
        oldDelegate.successStart != successStart ||
        oldDelegate.successEnd != successEnd;
  }
}

class _PlayerAvatarMapMarker extends StatelessWidget {
  const _PlayerAvatarMapMarker({required this.equipped});

  final Map<String, String> equipped;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Colors.cyanAccent.withValues(alpha: 0.85),
                Colors.blueAccent.withValues(alpha: 0.22),
                Colors.transparent,
              ],
            ),
          ),
        ),
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.cyanAccent, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.cyanAccent.withValues(alpha: 0.45),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipOval(
            child: AvatarLayeredPreview(
              avatarState: AvatarProfileViewState.fromEquipped(equipped),
              size: 38,
            ),
          ),
        ),
      ],
    );
  }
}

class _FishingSpotMapMarker extends StatelessWidget {
  const _FishingSpotMapMarker({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final clustered = count > 1;
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.lightGreenAccent.shade100, Colors.green.shade700],
            ),
            border: Border.all(color: Colors.white, width: 2.4),
            boxShadow: [
              BoxShadow(
                color: Colors.greenAccent.withValues(alpha: 0.55),
                blurRadius: 16,
                spreadRadius: 3,
              ),
            ],
          ),
          child: Icon(
            clustered ? Icons.radar : Icons.set_meal,
            color: Colors.white,
            size: clustered ? 18 : 21,
          ),
        ),
        if (clustered)
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.shade700,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _GameTopStatusBar extends StatelessWidget {
  const _GameTopStatusBar({
    required this.spotsShown,
    required this.spotsTotal,
    required this.checkpoints,
    required this.autoEnabled,
    required this.onToggleAuto,
  });

  final int spotsShown;
  final int spotsTotal;
  final int checkpoints;
  final bool autoEnabled;
  final VoidCallback onToggleAuto;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.75)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Colors.cyanAccent, Colors.blue.shade700],
                ),
              ),
              child: const Icon(Icons.radar, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'FisherGO 香港釣點雷達',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  Text(
                    '釣點 $spotsShown/$spotsTotal｜路徑 $checkpoints 點',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.blueGrey.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Semantics(
              button: true,
              excludeSemantics: true,
              label: catchLogRadarSemanticsLabel(autoEnabled),
              child: GestureDetector(
                onTap: onToggleAuto,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  decoration: BoxDecoration(
                    color: autoEnabled
                        ? Colors.greenAccent.withValues(alpha: 0.22)
                        : Colors.orangeAccent.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: autoEnabled ? Colors.green : Colors.orange,
                    ),
                  ),
                  child: Text(
                    autoEnabled ? 'AUTO' : 'MANUAL',
                    style: TextStyle(
                      color: autoEnabled
                          ? Colors.green.shade900
                          : Colors.orange.shade900,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameBottomCommandBar extends StatelessWidget {
  const _GameBottomCommandBar({
    required this.hasCurrent,
    required this.pendingCount,
    required this.baitSummary,
    required this.onAddCheckpoint,
    required this.onFishNearby,
  });

  final bool hasCurrent;
  final int pendingCount;
  final String baitSummary;
  final VoidCallback? onAddCheckpoint;
  final VoidCallback onFishNearby;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '附近釣魚挑戰',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  Text(
                    '$baitSummary｜待同步 $pendingCount',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.blueGrey.shade700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            IconButton.filledTonal(
              tooltip: '打卡',
              onPressed: onAddCheckpoint,
              icon: Icon(
                  hasCurrent ? Icons.add_location_alt : Icons.location_off),
            ),
            const SizedBox(width: 6),
            FilledButton.icon(
              onPressed: onFishNearby,
              icon: const Icon(Icons.set_meal),
              label: const Text('開釣'),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameSideHudButton extends StatelessWidget {
  const _GameSideHudButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(18),
            border:
                Border.all(color: Colors.cyanAccent.withValues(alpha: 0.85)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SizedBox(
            width: 56,
            height: 56,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.blue.shade800, size: 22),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GameHudButton extends StatelessWidget {
  const _GameHudButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.94),
                border: Border.all(color: Colors.cyanAccent, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.blue.shade800, size: 24),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.58),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapHudPill extends StatelessWidget {
  const _MapHudPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.75), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.28),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
            ),
          ),
        ],
      ),
    );
  }
}

class _RadarGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius =
        math.sqrt(size.width * size.width + size.height * size.height) / 2;
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.cyanAccent.withValues(alpha: 0.18);
    final beamPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.lightGreenAccent.withValues(alpha: 0.12);

    for (var i = 1; i <= 4; i++) {
      canvas.drawCircle(center, maxRadius * i / 4, ringPaint);
    }
    for (var angle = 0; angle < 360; angle += 45) {
      final radians = angle * math.pi / 180;
      final end = Offset(
        center.dx + math.cos(radians) * maxRadius,
        center.dy + math.sin(radians) * maxRadius,
      );
      canvas.drawLine(center, end, beamPaint);
    }

    final sweepPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          Colors.transparent,
          Colors.cyanAccent.withValues(alpha: 0.16),
          Colors.transparent,
        ],
        stops: const [0.0, 0.08, 0.18],
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius));
    canvas.drawCircle(center, maxRadius, sweepPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RenderedSpot {
  const _RenderedSpot({
    required this.spots,
    required this.latitude,
    required this.longitude,
  });

  final List<_FishingSpot> spots;
  final double latitude;
  final double longitude;
}

class _SpotCommunityService {
  _SpotCommunityService({
    required SupabaseClient? client,
    required Map<String, String> speciesById,
  })  : _client = client,
        _speciesById = speciesById;

  final SupabaseClient? _client;
  final Map<String, String> _speciesById;

  Future<List<String>> fetchOtherPlayersSpecies({
    required double centerLat,
    required double centerLng,
    required double radiusMeters,
    int days = 30,
  }) async {
    final client = _client;
    if (client == null) return const [];
    final currentUser = client.auth.currentUser;
    if (currentUser == null) return const [];

    final now = DateTime.now().toUtc();
    final from = now.subtract(Duration(days: days));
    final latDelta = radiusMeters / 111000.0;
    final lngDelta = radiusMeters / (111000.0 * _safeCos(centerLat));

    try {
      var query = client
          .from('catches')
          .select(
              'user_id,species_id,species_name,latitude,longitude,caught_at')
          .gte('caught_at', from.toIso8601String())
          .lte('caught_at', now.toIso8601String())
          .gte('latitude', centerLat - latDelta)
          .lte('latitude', centerLat + latDelta)
          .gte('longitude', centerLng - lngDelta)
          .lte('longitude', centerLng + lngDelta);

      query = query.neq('user_id', currentUser.id);
      final raw = await query;
      final rows = List<Map<String, dynamic>>.from(raw);

      final species = <String>{};
      for (final row in rows) {
        final lat = (row['latitude'] as num?)?.toDouble();
        final lng = (row['longitude'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;

        final distance =
            Geolocator.distanceBetween(centerLat, centerLng, lat, lng);
        if (distance > radiusMeters) continue;

        final speciesName = (row['species_name'] as String?)?.trim();
        if (speciesName != null && speciesName.isNotEmpty) {
          species.add(speciesName);
          continue;
        }

        final speciesId = (row['species_id'] as String?)?.trim();
        if (speciesId != null && speciesId.isNotEmpty) {
          species.add(_speciesById[speciesId] ?? '未知魚種');
        }
      }

      final sorted = species.toList()..sort();
      return sorted;
    } catch (_) {
      return const [];
    }
  }

  double _safeCos(double latDegree) {
    final radians = latDegree * 3.141592653589793 / 180.0;
    final value = math.cos(radians);
    return value.abs() < 0.2 ? 0.2 : value.abs();
  }
}

class _FishingSpot {
  const _FishingSpot({
    required this.id,
    required this.name,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.isIsland,
    required this.radiusMeters,
    required this.otherPlayersSpecies,
  });

  final String id;
  final String name;
  final String category;
  final double latitude;
  final double longitude;
  final bool isIsland;
  final double radiusMeters;
  final List<String> otherPlayersSpecies;
}

final List<_FishingSpot> _hkFishingSpots = hkFishingSpotsGeocodedSeed
    .where((spot) => spot.type == 'pier')
    .map(
      (spot) => _FishingSpot(
        id: spot.id,
        name: spot.displayName,
        category: spot.category,
        latitude: spot.latitude,
        longitude: spot.longitude,
        isIsland: spot.isIsland,
        radiusMeters: spot.radiusMeters,
        otherPlayersSpecies: const [],
      ),
    )
    .toList(growable: false);
