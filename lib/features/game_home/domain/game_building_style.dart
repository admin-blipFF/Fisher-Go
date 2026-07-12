import 'package:flutter/material.dart';

import 'terrain_data_source.dart';

class GameBuildingStyle {
  const GameBuildingStyle({
    required this.extrusionPixels,
    required this.roofColor,
    required this.sideColor,
    required this.outlineColor,
    required this.drawRoofDetail,
  });

  factory GameBuildingStyle.forFeature(
    TerrainVectorFeature feature, {
    required double depthScale,
    required bool simplified,
  }) {
    final height = (feature.heightMeters ?? 14).clamp(6, 60).toDouble();
    final extrusion = (height * 0.16 * depthScale).clamp(3, 15).toDouble();
    return GameBuildingStyle(
      extrusionPixels: extrusion,
      roofColor: const Color(0xFFD9E2DC),
      sideColor: const Color(0xFF728C91),
      outlineColor: const Color(0xFF28484E),
      drawRoofDetail: !simplified,
    );
  }

  final double extrusionPixels;
  final Color roofColor;
  final Color sideColor;
  final Color outlineColor;
  final bool drawRoofDetail;
}
