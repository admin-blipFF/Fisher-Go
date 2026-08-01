import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('MapLibre proof is isolated behind a feature flag', () {
    final source = File(
      'lib/features/map_proof/presentation/maplibre_proof_screen.dart',
    );
    final mapSurface = File(
      'lib/features/map/presentation/game_map_libre.dart',
    );

    expect(source.existsSync(), isTrue);
    expect(mapSurface.existsSync(), isTrue);
    final contents = source.readAsStringSync();
    final mapContents = mapSurface.readAsStringSync();

    expect(mapContents, contains("package:maplibre/maplibre.dart"));
    expect(mapContents, contains('MapLibreMap'));
    expect(mapContents, contains('fisherGoMapStyle'));
    expect(
      mapContents,
      isNot(contains('https://tiles.openfreemap.org/styles/liberty')),
    );
    expect(mapContents, isNot(contains('VectorSource(')));
    expect(mapContents, isNot(contains('addSource(')));
    expect(mapContents, contains('MapGestures.all'));
    expect(mapContents, contains('GameMapMarkerLayer'));
    expect(contents, contains('GameMapLibre'));
    expect(contents, contains('enabled'));
    expect(contents, contains('initialZoom: widget.initialZoom'));
    expect(contents, contains('initialPitch: widget.initialPitch'));
    expect(contents, contains('initialBearing: widget.initialBearing'));
    expect(contents, contains('onBearingChanged(90)'));
    expect(contents, contains('onBearingChanged(180)'));
    expect(contents, contains('onBearingChanged(270)'));

    final entrypoint = File('lib/map_proof_main.dart');
    expect(entrypoint.existsSync(), isTrue);
    final entrypointContents = entrypoint.readAsStringSync();
    expect(entrypointContents, contains('MapLibreProofScreen'));
    expect(entrypointContents, contains('const _proofLatitudeRaw'));
    expect(entrypointContents, contains('String.fromEnvironment'));
    expect(entrypointContents, contains('FISHERGO_MAP_PROOF_LAT'));
    expect(entrypointContents, contains('FISHERGO_MAP_PROOF_LON'));
    expect(entrypointContents, contains('FISHERGO_MAP_PROOF_ZOOM'));
    expect(entrypointContents, contains('FISHERGO_MAP_PROOF_PITCH'));
    expect(entrypointContents, contains('FISHERGO_MAP_PROOF_BEARING'));

    final webIndex = File('web/index.html');
    final webIndexContents = webIndex.readAsStringSync();
    expect(webIndexContents, contains('pmtiles@4.3.0/dist/pmtiles.js'));
  });
}
