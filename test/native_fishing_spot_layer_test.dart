import 'package:fishergo/features/map/domain/game_map_spot.dart';
import 'package:fishergo/features/map/presentation/native_fishing_spot_layer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre/maplibre.dart';

void main() {
  const spots = [
    GameMapSpot(
      id: 'open',
      name: '公開釣點',
      latitude: 22.38,
      longitude: 114.18,
    ),
    GameMapSpot(
      id: 'locked',
      name: '鎖定釣點',
      latitude: 22.381,
      longitude: 114.181,
      locked: true,
    ),
    GameMapSpot(
      id: 'selected',
      name: '已選釣點',
      latitude: 22.382,
      longitude: 114.182,
    ),
  ];

  test('native layers keep spot states and stable query properties', () {
    final layers = buildNativeFishingSpotLayers(
      spots,
      selectedSpotId: 'selected',
    );

    expect(layers, hasLength(4));
    expect((layers[0] as CircleLayer).list, hasLength(1));
    expect((layers[1] as CircleLayer).list, hasLength(1));
    expect((layers[2] as CircleLayer).list, hasLength(1));
    expect((layers[3] as MarkerLayer).list, hasLength(2));

    final selectedFeature = (layers[1] as CircleLayer).list.single;
    expect(selectedFeature.id, 'selected');
    expect(selectedFeature.properties['spot_id'], 'selected');
    expect(selectedFeature.properties['label'], '已選釣點');
  });

  test('native marker layer can use the transparent game beacon asset', () {
    final layers = buildNativeFishingSpotLayers(
      spots,
      selectedSpotId: 'selected',
      spotIconImageId: nativeFishingSpotIconImageId,
    );

    final markerLayer = layers[3] as MarkerLayer;
    expect(markerLayer.iconImage, nativeFishingSpotIconImageId);
    expect(markerLayer.iconAllowOverlap, isTrue);
    expect(markerLayer.iconIgnorePlacement, isTrue);
    expect(markerLayer.iconAnchor, IconAnchor.bottom);
    expect(markerLayer.iconSize, 0.18);
  });

  test('native layers can omit labels for constrained Android rendering', () {
    final layers = buildNativeFishingSpotLayers(
      spots,
      selectedSpotId: 'selected',
      includeLabels: false,
    );

    expect(layers, hasLength(3));
    expect(layers, everyElement(isA<CircleLayer>()));
  });

  test('native query result resolves only a known fishing spot', () {
    expect(
      resolveNativeFishingSpot(
        const [
          RenderedFeature(
            id: 'ignored',
            properties: {'spot_id': 'selected'},
          ),
        ],
        spots,
      )?.id,
      'selected',
    );
    expect(
      resolveNativeFishingSpot(
        const [
          RenderedFeature(
            id: 'unknown',
            properties: {'spot_id': 'not-in-registry'},
          ),
        ],
        spots,
      ),
      isNull,
    );
  });
}
