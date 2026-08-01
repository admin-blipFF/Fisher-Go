import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:maplibre/maplibre.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../../../core/config/public_app_config.dart';

/// FisherGO-owned upright marker overlay.
///
/// Reading MapCamera makes this layer depend on MapLibre's inherited camera
/// state. That keeps upright game markers projected to the current camera on
/// Web rotation and pan without rebuilding the whole map widget.
class GameMapMarkerLayer extends StatefulWidget {
  const GameMapMarkerLayer({super.key, required this.markers});

  final List<GameMapMarker> markers;

  @override
  State<GameMapMarkerLayer> createState() => _GameMapMarkerLayerState();
}

class _GameMapMarkerLayerState extends State<GameMapMarkerLayer> {
  List<Geographic> _projectedPoints = const <Geographic>[];

  @override
  void initState() {
    super.initState();
    _cacheMarkerPoints(widget.markers);
  }

  @override
  void didUpdateWidget(covariant GameMapMarkerLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.markers, widget.markers)) {
      _cacheMarkerPoints(widget.markers);
    }
  }

  void _cacheMarkerPoints(List<GameMapMarker> markers) {
    _projectedPoints = List<Geographic>.unmodifiable(
      markers.map((marker) => marker.point),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = MapController.maybeOf(context);
    final camera = MapCamera.maybeOf(context);
    if (controller == null || (kIsWeb && camera == null)) {
      return const SizedBox.shrink();
    }

    final offsets = controller.toScreenLocations(_projectedPoints);
    if (PublicAppConfig.mapMarkerProjectionDebugEnabled) {
      debugPrint(
        'FisherGO marker projections: ${[
          for (var index = 0; index < offsets.length; index++)
            '$index:${offsets[index].dx.toStringAsFixed(1)},'
                '${offsets[index].dy.toStringAsFixed(1)}',
        ].join('|')}',
      );
    }

    return Stack(
      children: [
        for (var index = 0; index < widget.markers.length; index++)
          _positionMarker(widget.markers[index], offsets[index]),
      ],
    );
  }

  Widget _positionMarker(GameMapMarker marker, Offset anchor) {
    final child = marker.interactive && kIsWeb
        ? PointerInterceptor(child: marker.child)
        : marker.child;
    return Positioned(
      left: anchor.dx - marker.size.width / 2 * (marker.alignment.x + 1),
      top: anchor.dy - marker.size.height / 2 * (marker.alignment.y + 1),
      width: marker.size.width,
      height: marker.size.height,
      child: RepaintBoundary(child: child),
    );
  }
}

@immutable
class GameMapMarker {
  const GameMapMarker({
    required this.point,
    required this.size,
    required this.child,
    this.alignment = Alignment.center,
    this.interactive = false,
  });

  final Geographic point;
  final Size size;
  final Alignment alignment;
  final bool interactive;
  final Widget child;
}
