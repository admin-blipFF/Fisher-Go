import 'package:flutter/material.dart';

/// 地圖上的釣點標記（可顯示叢集數量）
class FishingSpotMarker extends StatelessWidget {
  const FishingSpotMarker({super.key, required this.count});

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
