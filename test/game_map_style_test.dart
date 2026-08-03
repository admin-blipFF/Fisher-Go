import 'dart:convert';

import 'package:fishergo/features/map/presentation/game_map_style.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FisherGO map style keeps only gameplay-critical vector layers', () {
    final style = jsonDecode(fisherGoMapStyle) as Map<String, dynamic>;
    final sources = style['sources'] as Map<String, dynamic>;
    final source = sources['openmaptiles'] as Map<String, dynamic>;
    final layers =
        (style['layers'] as List<dynamic>).cast<Map<String, dynamic>>();
    final layerIds = layers.map((layer) => layer['id']).toSet();

    expect(style['version'], 8);
    expect(source['type'], 'vector');
    expect(source['url'], 'https://tiles.openfreemap.org/planet');
    expect(layers.length, lessThanOrEqualTo(19));
    expect(layers.any((layer) => layer['type'] == 'symbol'), isFalse);
    expect(
      layerIds,
      containsAll(<String>{
        'land',
        'landuse',
        'park',
        'water',
        'waterway',
        'building-3d',
        'road-major',
        'road-minor',
        'pier',
      }),
    );
  });

  test('full game style uses classified land use and water fills', () {
    final style = jsonDecode(fisherGoMapStyle) as Map<String, dynamic>;
    final layers =
        (style['layers'] as List<dynamic>).cast<Map<String, dynamic>>();
    final landuse = layers.firstWhere((layer) => layer['id'] == 'landuse');
    final water = layers.firstWhere((layer) => layer['id'] == 'water');

    expect(landuse['source-layer'], 'landuse');
    expect(landuse['filter'], contains('residential'));
    expect(landuse['filter'], contains('industrial'));
    expect((landuse['paint'] as Map<String, dynamic>)['fill-color'],
        isA<List<dynamic>>());
    expect((water['paint'] as Map<String, dynamic>)['fill-color'],
        isA<List<dynamic>>());
  });

  test('Web motion style preserves full geography without extrusion', () {
    final full = jsonDecode(fisherGoMapStyle) as Map<String, dynamic>;
    final motion =
        jsonDecode(fisherGoWebMotionMapStyle) as Map<String, dynamic>;
    final fullLayers =
        (full['layers'] as List<dynamic>).cast<Map<String, dynamic>>();
    final motionLayers =
        (motion['layers'] as List<dynamic>).cast<Map<String, dynamic>>();
    final fullIds = fullLayers.map((layer) => layer['id']).toSet();
    final motionIds = motionLayers.map((layer) => layer['id']).toSet();

    const excludedIds = <String>{
      'building-3d',
      'road-path',
      'road-minor-casing',
      'road-minor',
      'road-medium-casing',
      'road-major-casing',
      'pier-casing',
    };
    expect(motionLayers.length, fullLayers.length - excludedIds.length);
    expect(motionIds, containsAll(fullIds.difference(excludedIds)));
    expect(motionIds.intersection(excludedIds), isEmpty);
    expect(motionIds, contains('building'));
    expect(motionIds, containsAll(<String>{'water', 'waterway', 'road-major'}));
  });

  test('Web motion style keeps main roads without duplicate road passes', () {
    final motion =
        jsonDecode(fisherGoWebMotionMapStyle) as Map<String, dynamic>;
    final layers =
        (motion['layers'] as List<dynamic>).cast<Map<String, dynamic>>();
    final ids = layers.map((layer) => layer['id']).toSet();

    expect(
        ids,
        containsAll(<String>{
          'water',
          'waterway',
          'building',
          'road-medium',
          'road-major',
          'pier',
        }));
    expect(ids, isNot(contains('road-path')));
    expect(ids, isNot(contains('road-minor')));
    expect(ids, isNot(contains('road-minor-casing')));
    expect(ids, isNot(contains('road-medium-casing')));
    expect(ids, isNot(contains('road-major-casing')));
    expect(ids, isNot(contains('pier-casing')));
  });

  test('compact map style keeps real geography with a bounded layer budget',
      () {
    final style = jsonDecode(fisherGoCompactMapStyle) as Map<String, dynamic>;
    final layers =
        (style['layers'] as List<dynamic>).cast<Map<String, dynamic>>();
    final layerIds = layers.map((layer) => layer['id']).toSet();

    expect(layers.length, lessThanOrEqualTo(12));
    expect(layers.any((layer) => layer['type'] == 'symbol'), isFalse);
    expect(
      layerIds,
      containsAll(<String>{
        'land',
        'water',
        'waterway',
        'building',
        'road-major',
        'road-minor',
        'pier',
      }),
    );
  });

  test('game 3D style keeps extrusion and real geography with a lean budget',
      () {
    final style = jsonDecode(fisherGoGame3dMapStyle) as Map<String, dynamic>;
    final layers =
        (style['layers'] as List<dynamic>).cast<Map<String, dynamic>>();
    final layerIds = layers.map((layer) => layer['id']).toSet();

    expect(layers.length, lessThanOrEqualTo(14));
    expect(layers.any((layer) => layer['type'] == 'symbol'), isFalse);
    expect(layerIds, isNot(contains('road-path')));
    expect(
      layerIds,
      containsAll(<String>{
        'land',
        'water',
        'waterway',
        'building-3d',
        'road-main',
        'pier',
      }),
    );
    final extrusion =
        layers.firstWhere((layer) => layer['id'] == 'building-3d');
    expect(extrusion['type'], 'fill-extrusion');
    final road = layers.firstWhere((layer) => layer['id'] == 'road-main');
    expect(
      (road['filter'] as List<dynamic>),
      containsAll(
          <String>{'motorway', 'trunk', 'primary', 'secondary', 'tertiary'}),
    );
    expect((road['filter'] as List<dynamic>), isNot(contains('minor')));
    expect((road['filter'] as List<dynamic>), isNot(contains('service')));
    final roadPaint = road['paint'] as Map<String, dynamic>;
    expect((roadPaint['line-color'] as List<dynamic>).first, 'match');
    expect((roadPaint['line-width'] as List<dynamic>).first, 'interpolate');
    expect(
      (roadPaint['line-width'] as List<dynamic>)
          .where((value) => value == 'interpolate')
          .length,
      1,
    );
    expect((roadPaint['line-color'] as List<dynamic>),
        isNot(contains('minor')));
    expect((roadPaint['line-color'] as List<dynamic>),
        isNot(contains('service')));
    expect((roadPaint['line-width'] as List<dynamic>),
        isNot(contains('minor')));
    expect((roadPaint['line-width'] as List<dynamic>),
        isNot(contains('service')));
  });

  test('fixed-height 3D diagnostic keeps geography but removes height lookup',
      () {
    final production =
        jsonDecode(fisherGoGame3dMapStyle) as Map<String, dynamic>;
    final diagnostic = jsonDecode(
      fisherGoFixedBuildingHeightGame3dMapStyle,
    ) as Map<String, dynamic>;
    final productionLayers =
        (production['layers'] as List<dynamic>).cast<Map<String, dynamic>>();
    final diagnosticLayers =
        (diagnostic['layers'] as List<dynamic>).cast<Map<String, dynamic>>();
    final productionIds = productionLayers.map((layer) => layer['id']).toSet();
    final diagnosticIds = diagnosticLayers.map((layer) => layer['id']).toSet();

    expect(diagnosticIds, productionIds);
    final extrusion =
        diagnosticLayers.firstWhere((layer) => layer['id'] == 'building-3d');
    final paint = extrusion['paint'] as Map<String, dynamic>;
    expect(paint['fill-extrusion-height'], 24);
    expect(paint['fill-extrusion-base'], 0);

    final productionPaint = productionLayers
        .firstWhere((layer) => layer['id'] == 'building-3d')['paint'] as
        Map<String, dynamic>;
    expect(productionPaint['fill-extrusion-height'], isA<List<dynamic>>());
  });

  test('low-power style keeps playable geography with a smaller draw budget',
      () {
    final style = jsonDecode(fisherGoLowPowerMapStyle) as Map<String, dynamic>;
    final layers =
        (style['layers'] as List<dynamic>).cast<Map<String, dynamic>>();
    final layerIds = layers.map((layer) => layer['id']).toSet();

    expect(layers.length, lessThanOrEqualTo(9));
    expect(layers.any((layer) => layer['type'] == 'symbol'), isFalse);
    expect(
      layerIds,
      containsAll(<String>{
        'land',
        'landcover',
        'water',
        'waterway',
        'road',
        'path',
        'pier',
      }),
    );
    expect(layerIds, isNot(contains('building')));
  });
}
