import 'package:maplibre/maplibre.dart';

/// MapLibre-owned player sprite used by the Android performance candidate.
///
/// The sprite is registered from the selected Flutter avatar at style-load
/// time. The point remains GPS-owned; the image is only a rendering material.
const nativePlayerImageId = 'fishergo-game-player-avatar';

List<Layer> buildNativePlayerLayer(
  Geographic player, {
  required String imageId,
}) {
  return [
    MarkerLayer(
      points: [
        Feature<Point>(
          geometry: Point.build([player.lon, player.lat]),
        ),
      ],
      iconImage: imageId,
      iconSize: 0.72,
      iconAllowOverlap: true,
      iconIgnorePlacement: true,
      iconKeepUpright: true,
      iconAnchor: IconAnchor.bottom,
      iconPadding: 0,
    ),
  ];
}
