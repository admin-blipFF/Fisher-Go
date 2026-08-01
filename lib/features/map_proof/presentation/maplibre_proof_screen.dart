import 'dart:async';

import 'package:flutter/material.dart';
import 'package:maplibre/maplibre.dart';

import '../../map/domain/game_map_spot.dart';
import '../../map/presentation/game_map_libre.dart';

/// An isolated MapLibre engine proof. It uses the same map surface as the
/// production home screen, with fixed test spots for marker interaction QA.
class MapLibreProofScreen extends StatefulWidget {
  const MapLibreProofScreen({
    super.key,
    this.enabled = true,
    this.initialCenter = const Geographic(lon: 114.187, lat: 22.382),
    this.initialZoom = 16.0,
    this.initialPitch = 45.0,
    this.initialBearing = 0.0,
    this.title = 'MapLibre engine proof',
  });

  final bool enabled;
  final Geographic initialCenter;
  final double initialZoom;
  final double initialPitch;
  final double initialBearing;
  final String title;

  @override
  State<MapLibreProofScreen> createState() => _MapLibreProofScreenState();
}

class _MapLibreProofScreenState extends State<MapLibreProofScreen> {
  MapController? _mapController;
  bool _mapReady = false;
  String? _selectedSpotId;
  String _status = '正在載入向量海圖…';

  static const _spots = [
    GameMapSpot(
      id: 'spot-shatin',
      name: '沙田測試釣點',
      latitude: 22.3855,
      longitude: 114.1915,
      markerColor: Color(0xFF10D9C4),
    ),
    GameMapSpot(
      id: 'spot-harbour',
      name: '維港測試釣點',
      latitude: 22.2934,
      longitude: 114.1719,
      markerColor: Color(0xFF43A5FF),
    ),
    GameMapSpot(
      id: 'spot-tsingma',
      name: '青馬測試釣點',
      latitude: 22.3522,
      longitude: 114.0638,
      markerColor: Color(0xFFFFB84A),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: const Center(
          child: Text('MapLibre proof is disabled for this build.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Stack(
        children: [
          GameMapLibre(
            playerLocation: widget.initialCenter,
            playerMarker: const _ProofPlayerMarker(),
            spots: _spots,
            selectedSpotId: _selectedSpotId,
            onSpotSelected: _selectSpot,
            onMapCreated: (controller) => _mapController = controller,
            onReady: _markReady,
            initialZoom: widget.initialZoom,
            initialPitch: widget.initialPitch,
            initialBearing: widget.initialBearing,
          ),
          Positioned(
            left: 16,
            right: 16,
            top: 16,
            child: _ProofStatusCard(
              mapReady: _mapReady,
              selectedSpot: _selectedSpot,
              status: _status,
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            top: 112,
            child: _BearingControls(onBearingChanged: _setBearing),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _resetNorth,
        icon: const Icon(Icons.explore),
        label: const Text('北向'),
      ),
    );
  }

  void _markReady() {
    if (!mounted) return;
    setState(() {
      _mapReady = true;
      _status = '向量圖層已載入，可旋轉、縮放及傾斜';
    });
  }

  void _selectSpot(GameMapSpot spot) {
    if (!mounted) return;
    setState(() {
      _selectedSpotId = spot.id;
      _status = '已選擇 ${spot.name}';
    });
  }

  GameMapSpot? get _selectedSpot {
    final selectedId = _selectedSpotId;
    if (selectedId == null) return null;
    for (final spot in _spots) {
      if (spot.id == selectedId) return spot;
    }
    return null;
  }

  void _resetNorth() {
    _setBearing(0);
  }

  void _setBearing(double bearing) {
    final controller = _mapController;
    if (controller == null) return;
    if (mounted) {
      setState(() => _status = '正在檢視 ${bearing.toInt()}° 方向');
    }
    unawaited(
      controller.animateCamera(
        bearing: bearing,
        pitch: widget.initialPitch,
        nativeDuration: const Duration(milliseconds: 250),
        webSpeed: 1.4,
      ),
    );
  }
}

class _BearingControls extends StatelessWidget {
  const _BearingControls({required this.onBearingChanged});

  final ValueChanged<double> onBearingChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _BearingButton(bearing: 0, onPressed: () => onBearingChanged(0)),
          _BearingButton(bearing: 90, onPressed: () => onBearingChanged(90)),
          _BearingButton(
            bearing: 180,
            onPressed: () => onBearingChanged(180),
          ),
          _BearingButton(
            bearing: 270,
            onPressed: () => onBearingChanged(270),
          ),
        ],
      ),
    );
  }
}

class _BearingButton extends StatelessWidget {
  const _BearingButton({required this.bearing, required this.onPressed});

  final int bearing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '設定地圖方向 $bearing 度',
      child: TextButton(
        onPressed: onPressed,
        child: Text('$bearing°'),
      ),
    );
  }
}

class _ProofPlayerMarker extends StatelessWidget {
  const _ProofPlayerMarker();

  @override
  Widget build(BuildContext context) {
    return const CircleAvatar(
      radius: 24,
      backgroundColor: Color(0xFFF7FFFF),
      child: Icon(Icons.person, color: Color(0xFF087F8C), size: 30),
    );
  }
}

class _ProofStatusCard extends StatelessWidget {
  const _ProofStatusCard({
    required this.mapReady,
    required this.selectedSpot,
    required this.status,
  });

  final bool mapReady;
  final GameMapSpot? selectedSpot;
  final String status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      color: colorScheme.surface.withValues(alpha: 0.94),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(
              mapReady ? Icons.check_circle : Icons.sync,
              color: mapReady ? Colors.green.shade700 : colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$status\nMap: ${mapReady ? 'ready' : 'loading'} · Spot: ${selectedSpot?.name ?? '未選擇'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
