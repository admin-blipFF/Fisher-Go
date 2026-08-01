import 'package:fishergo/features/map/presentation/native_player_layer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre/maplibre.dart';

void main() {
  test('native player layer preserves the GPS point and stays upright', () {
    const player = Geographic(lon: 114.1874, lat: 22.3819);

    final layers = buildNativePlayerLayer(
      player,
      imageId: nativePlayerImageId,
    );

    expect(layers, hasLength(1));
    final layer = layers.single as MarkerLayer;
    expect(layer.list, hasLength(1));
    expect(layer.iconImage, nativePlayerImageId);
    expect(layer.iconAllowOverlap, isTrue);
    expect(layer.iconIgnorePlacement, isTrue);
    expect(layer.iconKeepUpright, isTrue);
    expect(layer.iconAnchor, IconAnchor.bottom);
    expect(layer.iconSize, 0.72);

    final point = layer.list.single.geometry!;
    expect(point.position[0], player.lon);
    expect(point.position[1], player.lat);
  });
}
