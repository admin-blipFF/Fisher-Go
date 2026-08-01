import 'dart:ui';

import 'package:maplibre/maplibre.dart';

import '../domain/game_map_spot.dart';

/// The declarative layer order is part of the click-query contract.
const nativeFishingSpotLayerIds = <String>[
  'maplibre-layer-0',
  'maplibre-layer-1',
  'maplibre-layer-2',
  'maplibre-layer-3',
];

const nativeFishingSpotIconImageId = 'fishergo-fishing-spot-beacon';
const nativeFishingSpotIconAsset =
    'assets/fishing/map_markers/fishing_spot_beacon_3d.png';

/// Builds MapLibre-owned spot geometry while keeping the domain model as the
/// source of truth for labels, lock state, and selection.
List<Layer> buildNativeFishingSpotLayers(
  List<GameMapSpot> spots, {
  String? selectedSpotId,
  String? spotIconImageId,
  bool includeLabels = true,
}) {
  final unlocked = <Feature<Point>>[];
  final selected = <Feature<Point>>[];
  final locked = <Feature<Point>>[];
  final labels = <Feature<Point>>[];

  for (final spot in spots) {
    final feature = _spotFeature(spot);
    if (spot.locked) {
      locked.add(feature);
    } else if (spot.id == selectedSpotId) {
      selected.add(feature);
    } else {
      unlocked.add(feature);
    }
    if (includeLabels && !spot.locked) labels.add(feature);
  }

  final layers = <Layer>[
    CircleLayer(
      points: unlocked,
      radius: 11,
      color: const Color(0xFF12D9C5),
      strokeWidth: 3,
      strokeColor: const Color(0xFF075B65),
    ),
    CircleLayer(
      points: selected,
      radius: 15,
      color: const Color(0xFFFFD166),
      strokeWidth: 4,
      strokeColor: const Color(0xFFFFFFFF),
    ),
    CircleLayer(
      points: locked,
      radius: 10,
      color: const Color(0xFF8A9BA0),
      strokeWidth: 3,
      strokeColor: const Color(0xFF3D555B),
    ),
  ];
  if (includeLabels) {
    layers.add(
      MarkerLayer(
        points: labels,
        iconImage: spotIconImageId,
        iconSize: 0.18,
        iconAllowOverlap: true,
        iconIgnorePlacement: true,
        iconOptional: true,
        iconAnchor: IconAnchor.bottom,
        textField: '{label}',
        textSize: 11,
        textColor: const Color(0xFFFFFFFF),
        textHaloColor: const Color(0xFF0A2A32),
        textHaloWidth: 1.5,
        textAllowOverlap: true,
        textIgnorePlacement: true,
        textOffset: const [0, 2],
      ),
    );
  }
  return layers;
}

/// Resolves a native map query through the stable domain property, rather
/// than relying on platform-specific feature id conversion.
GameMapSpot? resolveNativeFishingSpot(
  List<RenderedFeature> features,
  List<GameMapSpot> spots,
) {
  final byId = <String, GameMapSpot>{
    for (final spot in spots) spot.id: spot,
  };
  for (final feature in features) {
    final id = feature.properties['spot_id'];
    if (id is! String) continue;
    final spot = byId[id];
    if (spot != null) return spot;
  }
  return null;
}

Feature<Point> _spotFeature(GameMapSpot spot) => Feature<Point>(
      id: spot.id,
      geometry: Point.build([spot.longitude, spot.latitude]),
      properties: {'spot_id': spot.id, 'label': spot.displayLabel},
    );
