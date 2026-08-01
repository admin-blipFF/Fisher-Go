import 'package:flutter/material.dart';

/// 底部指令列 — 顯示魚餌摘要、打卡按鈕、「開釣」按鈕
class GameBottomCommandBar extends StatelessWidget {
  const GameBottomCommandBar({
    super.key,
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
