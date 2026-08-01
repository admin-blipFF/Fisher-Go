import 'package:flutter/material.dart';
import 'package:maplibre/maplibre.dart';

import 'features/map_proof/presentation/maplibre_proof_screen.dart';

const _proofLatitudeRaw = String.fromEnvironment('FISHERGO_MAP_PROOF_LAT');
const _proofLongitudeRaw = String.fromEnvironment('FISHERGO_MAP_PROOF_LON');
const _proofZoomRaw = String.fromEnvironment('FISHERGO_MAP_PROOF_ZOOM');
const _proofPitchRaw = String.fromEnvironment('FISHERGO_MAP_PROOF_PITCH');
const _proofBearingRaw = String.fromEnvironment('FISHERGO_MAP_PROOF_BEARING');

double _proofDouble(String raw, double fallback) {
  return double.tryParse(raw) ?? fallback;
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MapLibreProofScreen(
        initialCenter: Geographic(
          lon: _proofDouble(_proofLongitudeRaw, 114.187),
          lat: _proofDouble(_proofLatitudeRaw, 22.382),
        ),
        initialZoom: _proofDouble(_proofZoomRaw, 16.0),
        initialPitch: _proofDouble(_proofPitchRaw, 45.0),
        initialBearing: _proofDouble(_proofBearingRaw, 0.0),
      ),
    ),
  );
}
