import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:maplibre/maplibre.dart';

@immutable
class GameMapSpot {
  const GameMapSpot({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.markerColor = const Color(0xFF12D9C5),
    this.locked = false,
  });

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final Color markerColor;
  final bool locked;

  Geographic get point => Geographic(lon: longitude, lat: latitude);

  String get displayLabel => name.trim().isEmpty ? id : name.trim();
}
