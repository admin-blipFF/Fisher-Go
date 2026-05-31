import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../fish/data/sample_fish_species_data_source.dart';
import '../../fish/domain/fish_species.dart';
import '../../profile/data/profile_wallet_service.dart';
import '../data/catch_log_local_data_source.dart';
import '../data/catch_sync_service.dart';
import '../data/hk_fishing_spots_geocoded_seed.dart';
import '../domain/catch_log_entry.dart';

class CatchLogScreen extends StatefulWidget {
  const CatchLogScreen({
    super.key,
    this.localDataSource,
    this.syncService,
    this.mapOnly = false,
  });

  final CatchLogLocalDataSource? localDataSource;
  final CatchSyncService? syncService;
  final bool mapOnly;

  @override
  State<CatchLogScreen> createState() => _CatchLogScreenState();
}

class _CatchLogScreenState extends State<CatchLogScreen> {
  final _formKey = GlobalKey<FormState>();
  final _lengthController = TextEditingController();
  final _weightController = TextEditingController();
  final _notesController = TextEditingController();
  final MapController _mapController = MapController();

  late final CatchLogLocalDataSource _localDataSource;
  late final CatchSyncService _syncService;
  late final List<FishSpecies> _species;
  late final _SpotCommunityService _spotCommunityService;
  List<CatchLogEntry> _pending = const [];

  String? _selectedSpeciesId;
  DateTime _caughtAt = DateTime.now();
  String? _photoPath;
  double? _latitude;
  double? _longitude;
  final List<CatchCheckpoint> _checkpoints = [];
  final Set<String> _autoCheckedSpotIds = <String>{};
  final Map<String, List<String>> _otherSpeciesCache = <String, List<String>>{};
  StreamSubscription<Position>? _positionSubscription;
  var _autoCheckpointEnabled = true;
  var _saving = false;
  var _loadingOtherSpecies = false;
  double _mapZoom = 11;

  @override
  void initState() {
    super.initState();
    _localDataSource = widget.localDataSource ?? CatchLogLocalDataSource();
    _syncService = widget.syncService ??
        CatchSyncService(
          remote: SupabaseCatchRemoteDataSource(Supabase.instance.client),
        );
    _species = const SampleFishSpeciesDataSource().loadSpecies();
    _spotCommunityService = _SpotCommunityService(
      client: Supabase.instance.client,
      speciesById: {
        for (final fish in _species) fish.id: fish.displayNameLocalSlashCommon,
      },
    );
    if (_species.isNotEmpty) {
      _selectedSpeciesId = _species.first.id;
    }
    _loadPending();
    _startLocationTracking();
  }

  Future<void> _loadPending() async {
    final entries = await _localDataSource.loadPending();
    if (!mounted) return;
    setState(() => _pending = entries);
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _lengthController.dispose();
    _weightController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.mapOnly ? '地圖打卡（Pokemon GO 風）' : '魚獲記錄（離線佇列）'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: widget.mapOnly
            ? [
                _buildCheckpointSection(),
                const SizedBox(height: 16),
                _buildPendingList(),
              ]
            : [
                _buildInfoBanner(),
                const SizedBox(height: 12),
                _buildForm(context),
                const SizedBox(height: 16),
                _buildPendingList(),
              ],
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '目前為 Web MVP：先儲存到本地待同步佇列。未來接上 Supabase 後會自動同步。\n待同步：${_pending.length} 筆',
            ),
            const SizedBox(height: 10),
            FilledButton.tonalIcon(
              onPressed: _pending.isEmpty ? null : _syncPending,
              icon: const Icon(Icons.cloud_upload),
              label: const Text('同步到 Supabase'),
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
          DropdownButtonFormField<String>(
            initialValue: _selectedSpeciesId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: '魚種'),
            items: _species
                .map(
                  (fish) => DropdownMenuItem(
                    value: fish.id,
                    child: Tooltip(
                      message: fish.displayNameLocalSlashCommon,
                      child: Text(
                        fish.displayNameLocalSlashCommon,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                )
                .toList(growable: false),
            selectedItemBuilder: (context) => _species
                .map(
                  (fish) => Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      fish.displayLocalName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) => setState(() => _selectedSpeciesId = value),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('釣獲時間'),
            subtitle: Text(_formatDateTime(_caughtAt)),
            trailing: FilledButton.tonal(
              onPressed: _pickDateTime,
              child: const Text('修改'),
            ),
          ),
          TextFormField(
            controller: _lengthController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: '長度（cm，可選）'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _weightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: '重量（kg，可選）'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _notesController,
            maxLines: 3,
            decoration: const InputDecoration(labelText: '備註（可選）'),
          ),
          const SizedBox(height: 12),
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
                onPressed: _pickLocation,
                icon: const Icon(Icons.my_location),
                label: const Text('使用位置'),
              ),
            ],
          ),
          if (_photoPath != null) ...[
            const SizedBox(height: 8),
            Text('相片：$_photoPath', maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
          if (_latitude != null && _longitude != null) ...[
            const SizedBox(height: 8),
            Text('位置：${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}'),
          ],
          const SizedBox(height: 12),
          _buildCheckpointSection(),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save),
              label: Text(_saving ? '儲存中…' : '加入待同步佇列'),
            ),
          ),
        ],
      ),
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

  Widget _buildCheckpointSection() {
    final hasCurrent = _latitude != null && _longitude != null;
    final center = LatLng(_latitude ?? 22.3193, _longitude ?? 114.1694);

    final renderedSpots = _renderSpotsByZoom(_mapZoom);

    final markers = <Marker>[
      ...renderedSpots.map(
        (rendered) => Marker(
          point: LatLng(rendered.latitude, rendered.longitude),
          width: 44,
          height: 44,
          child: GestureDetector(
            onTap: () {
              if (rendered.spots.length == 1) {
                _showSpotBottomSheet(rendered.spots.first);
                return;
              }
              _showClusterBottomSheet(rendered);
            },
            child: rendered.spots.length == 1
                ? const Icon(Icons.place, color: Colors.green, size: 28)
                : Container(
                    decoration: BoxDecoration(
                      color: Colors.green.shade700,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${rendered.spots.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
          ),
        ),
      ),
      if (hasCurrent)
        Marker(
          point: LatLng(_latitude!, _longitude!),
          width: 36,
          height: 36,
          child: const Icon(Icons.my_location, color: Colors.blue, size: 24),
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
                  'Checkpoint 地圖（Pokemon GO 風）',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Chip(label: Text('顯示 ${renderedSpots.length}/${_hkFishingSpots.length}')),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('進入範圍自動打點'),
              subtitle: const Text('陸地 50m、海島 250m'),
              value: _autoCheckpointEnabled,
              onChanged: (value) => setState(() => _autoCheckpointEnabled = value),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: 220,
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: hasCurrent ? 15 : 11,
                    onPositionChanged: (position, _) {
                      final zoom = position.zoom;
                      if ((zoom - _mapZoom).abs() > 0.01 && mounted) {
                        setState(() => _mapZoom = zoom);
                      }
                    },
                    onTap: (_, point) => _addCheckpoint(point.latitude, point.longitude),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.fishergo.app',
                    ),
                    if (_mapZoom >= 12)
                      CircleLayer(
                        circles: _hkFishingSpots
                            .map(
                              (spot) => CircleMarker(
                                point: LatLng(spot.latitude, spot.longitude),
                                radius: spot.radiusMeters,
                                useRadiusInMeter: true,
                                color: spot.isIsland
                                    ? Colors.indigo.withValues(alpha: 0.12)
                                    : Colors.orange.withValues(alpha: 0.12),
                                borderColor: spot.isIsland ? Colors.indigo : Colors.orange,
                                borderStrokeWidth: 1.2,
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
                            color: Colors.red.withValues(alpha: 0.65),
                            strokeWidth: 3,
                          ),
                        ],
                      ),
                    MarkerLayer(markers: markers),
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

  Future<void> _startLocationTracking() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

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
      });
      unawaited(_autoCheckpointByGeofence());
    });
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
      setState(() => _photoPath = image.path);
    } catch (_) {
      _showSnack('此平台暫時無法選擇相片，先純文字記錄。');
    }
  }

  Future<void> _pickLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showSnack('未授權位置權限。');
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
      unawaited(_autoCheckpointByGeofence());
    } catch (_) {
      _showSnack('未能取得定位，請稍後再試。');
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
    await ProfileWalletService.addCoins(reward);
  }

  Future<void> _autoCheckpointByGeofence() async {
    if (!_autoCheckpointEnabled || _latitude == null || _longitude == null) return;



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

  List<_RenderedSpot> _renderSpotsByZoom(double zoom) {
    if (zoom >= 12.5) {
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

    final cellSize = zoom >= 11.5 ? 0.03 : 0.06;
    final buckets = <String, List<_FishingSpot>>{};

    for (final spot in _hkFishingSpots) {
      final latKey = (spot.latitude / cellSize).floor();
      final lonKey = (spot.longitude / cellSize).floor();
      final key = '$latKey:$lonKey';
      buckets.putIfAbsent(key, () => <_FishingSpot>[]).add(spot);
    }

    return buckets.values
        .map((spots) {
          final avgLat = spots.map((s) => s.latitude).reduce((a, b) => a + b) / spots.length;
          final avgLon = spots.map((s) => s.longitude).reduce((a, b) => a + b) / spots.length;
          return _RenderedSpot(spots: spots, latitude: avgLat, longitude: avgLon);
        })
        .toList(growable: false);
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
              Text('此區域 ${spots.length} 個釣點', style: Theme.of(context).textTheme.titleLarge),
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
                      subtitle: Text('${spot.category} · ${spot.radiusMeters.toStringAsFixed(0)}m'),
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
              Text('${spot.category} · 半徑 ${spot.radiusMeters.toStringAsFixed(0)}m'),
              const SizedBox(height: 12),
              Text('你曾釣到', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(mySpecies.isEmpty ? '暫無紀錄' : mySpecies.join('、')),
              const SizedBox(height: 12),
              Text('其他玩家曾釣到（30日）', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              if (_loadingOtherSpecies)
                const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Text(otherSpecies.isEmpty ? '暫無紀錄' : otherSpecies.join('、')),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _syncPending() async {
    if (_pending.isEmpty) return;

    setState(() => _saving = true);
    try {
      final summary = await _syncService.sync(_pending);
      if (summary.skipped > 0) {
        _showSnack('未登入或未設定 Supabase，暫未同步。');
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
            ),
          )
          .toList(growable: false);

      await _localDataSource.savePending(failedEntries);
      await _loadPending();
      _showSnack('同步完成：成功 ${summary.synced}，失敗 ${summary.failed}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _save() async {
    if (_selectedSpeciesId == null || !_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final fish = _species.firstWhere((item) => item.id == _selectedSpeciesId);
      final entry = CatchLogEntry(
        speciesId: fish.id,
        speciesName: fish.displayNameLocalSlashCommon,
        caughtAt: _caughtAt,
        lengthCm: _toDoubleOrNull(_lengthController.text),
        weightKg: _toDoubleOrNull(_weightController.text),
        notes: _emptyToNull(_notesController.text),
        photoPath: _photoPath,
        latitude: _latitude,
        longitude: _longitude,
        checkpoints: List<CatchCheckpoint>.unmodifiable(_checkpoints),
      );

      await _localDataSource.addPending(entry);
      await _loadPending();
      await ProfileWalletService.addCoins(20);

      _lengthController.clear();
      _weightController.clear();
      _notesController.clear();
      if (mounted) {
        setState(() {
          _photoPath = null;
          _latitude = null;
          _longitude = null;
          _checkpoints.clear();
        });
      }

      _showSnack('已加入本地待同步佇列（+20 金幣）');
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
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
    required SupabaseClient client,
    required Map<String, String> speciesById,
  })  : _client = client,
        _speciesById = speciesById;

  final SupabaseClient _client;
  final Map<String, String> _speciesById;

  Future<List<String>> fetchOtherPlayersSpecies({
    required double centerLat,
    required double centerLng,
    required double radiusMeters,
    int days = 30,
  }) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) return const [];

    final now = DateTime.now().toUtc();
    final from = now.subtract(Duration(days: days));
    final latDelta = radiusMeters / 111000.0;
    final lngDelta = radiusMeters / (111000.0 * _safeCos(centerLat));

    try {
      var query = _client
          .from('catches')
          .select('user_id,species_id,species_name,latitude,longitude,caught_at')
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

        final distance = Geolocator.distanceBetween(centerLat, centerLng, lat, lng);
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
