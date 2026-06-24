import 'package:flutter/material.dart';

/// 地圖 HUD 膠囊標籤（左上角雷達狀態 / GPS 狀態）
class MapHudPill extends StatelessWidget {
  const MapHudPill({
    super.key,
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