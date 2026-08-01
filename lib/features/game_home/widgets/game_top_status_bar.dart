import 'package:flutter/material.dart';

/// 遊戲頂部狀態列 — 顯示釣點雷達標題、釣點數量、路徑點數，以及 AUTO/MANUAL 切換
class GameTopStatusBar extends StatelessWidget {
  const GameTopStatusBar({
    super.key,
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
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Colors.cyanAccent, Colors.blue],
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
            GestureDetector(
              onTap: onToggleAuto,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
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
          ],
        ),
      ),
    );
  }
}
