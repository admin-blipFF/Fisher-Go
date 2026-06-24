import 'package:flutter/material.dart';

import '../../../domain/boat_vendor.dart';
import '../../../core/shop/boat_vendor_service.dart';

/// Shows the active boat vendor's route — one attempt per spot.
class BoatRouteScreen extends StatefulWidget {
  final BoatVendor vendor;
  final VoidCallback? onFishingStarted;

  /// Callback with (spotIndex, result) when spot fishing completes.
  final void Function(int index, String result)? onSpotResult;

  const BoatRouteScreen({
    super.key,
    required this.vendor,
    this.onFishingStarted,
    this.onSpotResult,
  });

  @override
  State<BoatRouteScreen> createState() => _BoatRouteScreenState();
}

class _BoatRouteScreenState extends State<BoatRouteScreen> {
  late List<String?> _spotStatus; // null=available, 'success', 'fail'

  @override
  void initState() {
    super.initState();
    _spotStatus = List.filled(widget.vendor.spotNames.length, null);
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    for (var i = 0; i < widget.vendor.spotNames.length; i++) {
      final attempted =
          await BoatVendorService.hasBoatSpotAttempted(widget.vendor.id, i);
      if (!mounted) return;
      setState(() => _spotStatus[i] = attempted ? 'done' : null);
    }
  }

  int get _doneCount => _spotStatus.where((s) => s != null).length;
  bool get _allDone => _doneCount == widget.vendor.spotNames.length;

  String _statusLabel(String? status) {
    return switch (status) {
      'success' => '✅ 成功',
      'fail' => '❌ 失敗',
      _ => '🎣 可作釣',
    };
  }

  Color _statusColor(String? status) {
    return switch (status) {
      'success' => Colors.green.shade700,
      'fail' => Colors.red.shade700,
      _ => Colors.blue.shade700,
    };
  }

  IconData _statusIcon(String? status) {
    return switch (status) {
      'success' => Icons.check_circle,
      'fail' => Icons.cancel,
      _ => Icons.phishing,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('🚤 ${widget.vendor.name} 路線'),
        backgroundColor: Colors.blue.shade900,
      ),
      body: Column(
        children: [
          // Route progress
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade800,
            child: Row(
              children: [
                const Icon(Icons.route, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.vendor.name} · ${widget.vendor.zoneName}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '已完成 $_doneCount / ${widget.vendor.spotNames.length} 個釣點',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _allDone ? Colors.green : Colors.orange,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _allDone ? '全部完成' : '進行中',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          // Spot list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: widget.vendor.spotNames.length,
              itemBuilder: (context, index) {
                final status = _spotStatus[index];
                final name = widget.vendor.spotNames[index];
                final location = widget.vendor.spotLocations[index];
                final done = status != null;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: CircleAvatar(
                      backgroundColor:
                          _statusColor(status).withValues(alpha: 0.2),
                      child: Icon(
                        _statusIcon(status),
                        color: _statusColor(status),
                      ),
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}',
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _statusColor(status).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _statusLabel(status),
                            style: TextStyle(
                              color: _statusColor(status),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    trailing: done
                        ? null
                        : FilledButton(
                            onPressed: () {
                              // Call onFishingStarted with spot index; parent
                              // (GameHomeScreen) should open the minigame for
                              // this spot and then call onSpotResult with the
                              // result.
                              widget.onFishingStarted?.call();
                              // Pop back so GameHomeScreen can react
                              Navigator.pop(context, index);
                            },
                            child: const Text('作釣'),
                          ),
                  ),
                );
              },
            ),
          ),
          // All-done banner
          if (_allDone)
            Container(
              padding: const EdgeInsets.all(20),
              color: Colors.green.shade700,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.emoji_events, color: Colors.amber, size: 32),
                  SizedBox(width: 12),
                  Text(
                    '路線完成！感謝乘搭',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
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
