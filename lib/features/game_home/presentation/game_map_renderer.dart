import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../domain/game_map_camera.dart';
import '../domain/game_map_feature_store.dart';
import '../domain/game_building_style.dart';
import '../domain/game_road_style.dart';
import '../domain/terrain_data_source.dart';

bool isRenderableBuildingFeature(TerrainVectorFeature feature) =>
    feature.kind == TerrainKind.building &&
    feature.isClosed &&
    feature.points.length >= 4;

class _ProjectedTerrainTile {
  const _ProjectedTerrainTile(this.data, this.center);

  final TerrainTile data;
  final Offset center;
}

class _RoadEndpoint {
  const _RoadEndpoint({required this.position, required this.style});

  final Offset position;
  final GameRoadStyle style;
}

enum _TerrainCellEdge { top, right, bottom, left }

enum _FishingSpotMarkerDetail { compact, full }

class GameMapRenderBudget {
  const GameMapRenderBudget({
    required this.enableDecorativeOverlays,
    required this.enableVectorTransitions,
    required this.enableRoadMicroDetails,
    required this.maxWashTiles,
    required this.maxVeilTiles,
    required this.maxLabels,
    required this.maxBuildings,
    required this.enableBuildingRoofDetail,
  });

  factory GameMapRenderBudget.forScene({
    required int terrainTileCount,
    required int terrainFeatureCount,
  }) {
    final heavyTileScene = terrainTileCount > 420;
    final heavyVectorScene = terrainFeatureCount > 70;
    final heavyScene = heavyTileScene || heavyVectorScene;
    return GameMapRenderBudget(
      enableDecorativeOverlays: !heavyScene,
      enableVectorTransitions: !heavyVectorScene && terrainTileCount <= 560,
      enableRoadMicroDetails: !heavyScene,
      maxWashTiles: heavyScene ? 170 : 360,
      maxVeilTiles: heavyScene ? 120 : 260,
      maxLabels: heavyScene ? 4 : 7,
      maxBuildings: heavyScene ? 30 : 72,
      enableBuildingRoofDetail: !heavyScene,
    );
  }

  final bool enableDecorativeOverlays;
  final bool enableVectorTransitions;
  final bool enableRoadMicroDetails;
  final int maxWashTiles;
  final int maxVeilTiles;
  final int maxLabels;
  final int maxBuildings;
  final bool enableBuildingRoofDetail;
}

class GameMapTexturePack {
  const GameMapTexturePack({
    this.water,
    this.land,
    this.grassMicro,
    this.grassLight,
    this.grassMid,
    this.grassDark,
    this.groundMoss,
    this.shoreGrass,
    this.shore,
    this.road,
  });

  final ui.Image? water;
  final ui.Image? land;
  final ui.Image? grassMicro;
  final ui.Image? grassLight;
  final ui.Image? grassMid;
  final ui.Image? grassDark;
  final ui.Image? groundMoss;
  final ui.Image? shoreGrass;
  final ui.Image? shore;
  final ui.Image? road;

  ui.Image? imageFor(TerrainKind kind) {
    return switch (kind) {
      TerrainKind.water => water,
      TerrainKind.land || TerrainKind.building => grassMicro ?? land,
      TerrainKind.shore => shore,
      TerrainKind.road => road,
      TerrainKind.pier => road,
      TerrainKind.fishingNode => null,
    };
  }

  ui.Image? microImageFor(TerrainKind kind) {
    return switch (kind) {
      TerrainKind.land => grassMicro,
      _ => imageFor(kind),
    };
  }

  ui.Image? landMicroImageForVariant(int variant) {
    final palette = [
      grassMid ?? grassMicro,
      grassLight ?? grassMicro,
      grassMid ?? grassMicro,
      grassDark ?? grassMicro,
      groundMoss ?? grassDark ?? grassMicro,
    ].whereType<ui.Image>().toList(growable: false);
    if (palette.isEmpty) return grassMicro ?? land;
    return palette[variant.abs() % palette.length];
  }
}

class GameMapRenderer extends StatefulWidget {
  const GameMapRenderer({
    super.key,
    required this.camera,
    required this.terrainTiles,
    required this.terrainFeatures,
    required this.fishingSpots,
  });

  final GameMapCamera camera;
  final List<TerrainTile> terrainTiles;
  final List<TerrainVectorFeature> terrainFeatures;
  final List<ProjectedFishingSpot> fishingSpots;

  @override
  State<GameMapRenderer> createState() => _GameMapRendererState();
}

class _GameMapRendererState extends State<GameMapRenderer> {
  static const _waterTexture = 'assets/maps/textures/water_tile.jpg';
  static const _landTexture = 'assets/maps/textures/land_tile.jpg';
  static const _grassMicroTexture = 'assets/maps/textures/grass_micro_tile.jpg';
  static const _grassLightTexture = 'assets/maps/textures/grass_light_tile.jpg';
  static const _grassMidTexture = 'assets/maps/textures/grass_mid_tile.jpg';
  static const _grassDarkTexture = 'assets/maps/textures/grass_dark_tile.jpg';
  static const _groundMossTexture = 'assets/maps/textures/ground_moss_tile.jpg';
  static const _shoreGrassTexture = 'assets/maps/textures/shore_grass_tile.jpg';
  static const _shoreTexture = 'assets/maps/textures/shore_tile.jpg';
  static const _roadTexture = 'assets/maps/textures/road_tile.jpg';

  GameMapTexturePack _texturePack = const GameMapTexturePack();

  @override
  void initState() {
    super.initState();
    _loadTextures();
  }

  Future<void> _loadTextures() async {
    try {
      final textures = GameMapTexturePack(
        water: await _loadTexture(_waterTexture),
        land: await _loadTexture(_landTexture),
        grassMicro: await _loadTexture(_grassMicroTexture),
        grassLight: await _loadTexture(_grassLightTexture),
        grassMid: await _loadTexture(_grassMidTexture),
        grassDark: await _loadTexture(_grassDarkTexture),
        groundMoss: await _loadTexture(_groundMossTexture),
        shoreGrass: await _loadTexture(_shoreGrassTexture),
        shore: await _loadTexture(_shoreTexture),
        road: await _loadTexture(_roadTexture),
      );
      if (!mounted) return;
      setState(() => _texturePack = textures);
    } catch (_) {
      if (!mounted) return;
      setState(() => _texturePack = const GameMapTexturePack());
    }
  }

  Future<ui.Image> _loadTexture(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    final bytes = Uint8List.view(
      data.buffer,
      data.offsetInBytes,
      data.lengthInBytes,
    );
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: GameMapPainter(
        camera: widget.camera,
        terrainTiles: widget.terrainTiles,
        terrainFeatures: widget.terrainFeatures,
        fishingSpots: widget.fishingSpots,
        texturePack: _texturePack,
      ),
      size: Size.infinite,
    );
  }
}

class GameMapPainter extends CustomPainter {
  const GameMapPainter({
    required this.camera,
    required this.terrainTiles,
    required this.terrainFeatures,
    required this.fishingSpots,
    this.texturePack = const GameMapTexturePack(),
  });

  final GameMapCamera camera;
  final List<TerrainTile> terrainTiles;
  final List<TerrainVectorFeature> terrainFeatures;
  final List<ProjectedFishingSpot> fishingSpots;
  final GameMapTexturePack texturePack;

  GameMapRenderBudget get _renderBudget => GameMapRenderBudget.forScene(
        terrainTileCount: terrainTiles.length,
        terrainFeatureCount: terrainFeatures.length,
      );

  @override
  void paint(Canvas canvas, Size size) {
    _drawHorizonLayer(canvas, size);
    if (_hasVectorWorldSurface) {
      _drawVectorWorldSurfaceLayer(canvas, size);
    } else {
      _drawVectorBaseSurface(canvas, size);
      _drawPerspectiveMicroTileLayer(canvas, size);
      _drawReadableTerrainToneLayer(canvas, size);
      _drawTerrainBoundaryBlendLayer(canvas, size);
      _drawTerrainDetailLayer(canvas, size);
    }
    _drawWorldSeamFusionLayer(canvas, size);
    _drawImagegenInspiredMapLayer(canvas, size);
    _drawCoastlineDepthLayer(canvas, size);
    _drawBuildingLayer(canvas, size);
    _drawRoadLayer(canvas, size);
    _drawPierLayer(canvas, size);
    _drawLandmarkLabelLayer(canvas, size);
    _drawFishingSpotLayer(canvas, size);
    _drawAtmosphereLayer(canvas, size);
  }

  bool get _hasVectorWorldSurface => terrainFeatures.any(
        (feature) =>
            feature.kind == TerrainKind.land &&
            feature.isClosed &&
            feature.points.length >= 3,
      );

  void _drawVectorWorldSurfaceLayer(Canvas canvas, Size size) {
    _drawVectorBaseSurface(canvas, size);
    _drawVectorWaterFeatures(canvas);
    _drawLandLayer(canvas, size);
    _drawCoastlineLayer(canvas, size);
  }

  TerrainKind get _vectorBaseTerrainKind {
    for (final kind in const [TerrainKind.land, TerrainKind.shore]) {
      for (final feature in terrainFeatures) {
        if (feature.kind == kind &&
            feature.isClosed &&
            terrainPolygonContains(camera.center, feature.points)) {
          return kind;
        }
      }
    }
    final surfaceTiles = terrainTiles.where(
      (tile) =>
          tile.kind == TerrainKind.land ||
          tile.kind == TerrainKind.shore ||
          tile.kind == TerrainKind.water,
    );
    if (surfaceTiles.isEmpty) return TerrainKind.water;
    final counts = <TerrainKind, int>{
      TerrainKind.land: 0,
      TerrainKind.shore: 0,
      TerrainKind.water: 0,
    };
    for (final tile in surfaceTiles) {
      counts[tile.kind] = counts[tile.kind]! + 1;
    }
    final majorityKind = counts.entries.reduce(
      (left, right) => left.value >= right.value ? left : right,
    );
    if (majorityKind.value > 1) return majorityKind.key;
    return surfaceTiles.reduce((left, right) {
      final leftDistance =
          (camera.project(left.centerLatLng) - camera.viewportCenter).distance;
      final rightDistance =
          (camera.project(right.centerLatLng) - camera.viewportCenter).distance;
      return leftDistance <= rightDistance ? left : right;
    }).kind;
  }

  void _drawVectorBaseSurface(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final baseKind = _vectorBaseTerrainKind;
    final isLand = baseKind == TerrainKind.land;
    final isShore = baseKind == TerrainKind.shore;
    if (isLand || isShore) {
      canvas.drawRect(rect, _paintForTerrainCell(baseKind, rect));
    }
    final texturePaint = _texturedFillPaint(
      baseKind,
      rect,
      fallbackColors: isLand
          ? const [Color(0xFF72D86D), Color(0xFF2FAE67)]
          : isShore
              ? const [Color(0xFFE8DB88), Color(0xFF69C983)]
              : const [
                  Color(0xFF6BE5E0),
                  Color(0xFF28B9CC),
                  Color(0xFF147B93),
                ],
      textureScale: isLand
          ? 0.082
          : isShore
              ? 0.075
              : 1.15,
    );
    if (isLand) {
      texturePaint.colorFilter = ColorFilter.mode(
        const Color(0xFFD6FFB0).withValues(alpha: 0.28),
        BlendMode.modulate,
      );
    } else if (isShore) {
      texturePaint.colorFilter = ColorFilter.mode(
        const Color(0xFFFFF0B6).withValues(alpha: 0.62),
        BlendMode.modulate,
      );
    }
    canvas.drawRect(
      rect,
      texturePaint,
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isLand
              ? const [Color(0x113FD36B), Color(0x221B8F59)]
              : const [Color(0x228EFFF7), Color(0x55063F54)],
        ).createShader(rect),
    );
  }

  void _drawVectorWaterFeatures(Canvas canvas) {
    for (final feature in terrainFeatures) {
      if (feature.kind != TerrainKind.water || !feature.isClosed) continue;
      final path = _pathForFeature(feature);
      if (path == null) continue;
      final bounds = path.getBounds();
      canvas.drawPath(
        path,
        _texturedFillPaint(
          TerrainKind.water,
          bounds,
          fallbackColors: const [Color(0xFF6BE5E0), Color(0xFF147B93)],
          textureScale: 1.15,
        ),
      );
      canvas.drawPath(
        path,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x337AF5EF), Color(0x66036C8C)],
          ).createShader(bounds),
      );
    }
  }

  void _drawHorizonLayer(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFA9ECFF),
            Color(0xFF83F0DF),
            Color(0xFF56C879),
            Color(0xFF1B8A67),
          ],
          stops: [0, 0.2, 0.54, 1],
        ).createShader(rect),
    );
    final hazeRect = Rect.fromLTWH(0, size.height * 0.14, size.width, 110);
    canvas.drawOval(
      hazeRect.inflate(size.width * 0.12),
      Paint()
        ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height * 0.42),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFFFFFFF).withValues(alpha: 0.25),
            Colors.transparent,
          ],
        ).createShader(rect),
    );
  }

  void _drawPerspectiveMicroTileLayer(Canvas canvas, Size size) {
    if (terrainTiles.isEmpty) return;
    final orderedTiles = terrainTiles
        .where((tile) => camera.isVisible(tile.centerLatLng, paddingMeters: 80))
        .toList()
      ..sort((a, b) {
        final rowCompare = a.row.compareTo(b.row);
        if (rowCompare != 0) return rowCompare;
        return a.col.compareTo(b.col);
      });
    final hasVectorRoadLayer = terrainFeatures.any((feature) =>
        feature.kind == TerrainKind.road || feature.kind == TerrainKind.pier);

    for (final tile in orderedTiles) {
      if ((tile.kind == TerrainKind.road || tile.kind == TerrainKind.pier) &&
          !hasVectorRoadLayer) {
        continue;
      }
      final renderTile = hasVectorRoadLayer &&
              (tile.kind == TerrainKind.road || tile.kind == TerrainKind.pier)
          ? TerrainTile(
              kind: TerrainKind.land,
              row: tile.row,
              col: tile.col,
              centerLatLng: tile.centerLatLng,
            )
          : tile;
      _drawPerspectiveTerrainCell(canvas, size, renderTile);
    }
    if (!hasVectorRoadLayer) {
      _drawPerspectiveRoadCells(canvas, size, orderedTiles);
    }
  }

  void _drawPerspectiveTerrainCell(
    Canvas canvas,
    Size size,
    TerrainTile tile,
  ) {
    final rect = _projectTileToPerspective(size, tile);
    if (rect == null) return;
    final path = _terrainCellPathFromCamera(rect, tile);
    canvas.drawPath(path, _paintForTerrainCell(tile.kind, rect));
    canvas.save();
    canvas.clipPath(path);
    _drawPerspectiveCellTexture(canvas, rect, tile.kind, tile.row + tile.col);
    canvas.restore();
    canvas.drawPath(
      path,
      Paint()
        ..color = _cellEdgeColor(tile.kind)
        ..style = PaintingStyle.stroke
        ..strokeWidth =
            tile.kind == TerrainKind.land || tile.kind == TerrainKind.water
                ? 0
                : 0.28,
    );
  }

  Rect? _projectTileToPerspective(Size size, TerrainTile tile) {
    return _projectTerrainCellFromCamera(size, tile);
  }

  Rect? _projectTerrainCellFromCamera(Size size, TerrainTile tile) {
    final rowCount = terrainTiles.map((tile) => tile.row).fold<int>(
              0,
              (max, row) => row > max ? row : max,
            ) +
        1;
    final colCount = terrainTiles.map((tile) => tile.col).fold<int>(
              0,
              (max, col) => col > max ? col : max,
            ) +
        1;
    if (rowCount <= 0 || colCount <= 0) return null;
    final center = camera.project(tile.centerLatLng);
    final depth = (center.dy / size.height).clamp(0.0, 1.0);
    final baseWidth = size.height / (colCount - 1);
    final baseHeight = size.height / (rowCount - 1);
    final perspective = 1.18 + depth * 0.42;
    final cellWidth = baseWidth * perspective * 1.46;
    final cellHeight = baseHeight * perspective * 1.72;
    if (center.dx < -cellWidth ||
        center.dx > size.width + cellWidth ||
        center.dy < -cellHeight ||
        center.dy > size.height + cellHeight) {
      return null;
    }
    return Rect.fromCenter(
      center: center,
      width: cellWidth,
      height: cellHeight,
    );
  }

  Path _terrainCellPathFromCamera(Rect rect, TerrainTile tile) {
    final isWater = tile.kind == TerrainKind.water;
    final isRoad =
        tile.kind == TerrainKind.road || tile.kind == TerrainKind.pier;
    if (isWater || isRoad) {
      return _perspectiveCellPath(rect);
    }
    final topInset = rect.width * 0.06;
    final sideInset = rect.width * 0.025;
    return Path()
      ..moveTo(rect.left + topInset, rect.top)
      ..lineTo(rect.right - topInset, rect.top)
      ..lineTo(rect.right - sideInset, rect.bottom)
      ..lineTo(rect.left + sideInset, rect.bottom)
      ..close();
  }

  Path _perspectiveCellPath(Rect rect) {
    final topInset = rect.width * 0.08;
    return Path()
      ..moveTo(rect.left + topInset, rect.top)
      ..lineTo(rect.right - topInset, rect.top)
      ..lineTo(rect.right, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
      ..close();
  }

  Paint _paintForTerrainCell(TerrainKind kind, Rect rect) {
    return Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: switch (kind) {
          TerrainKind.water => const [
              Color(0xFF71E8E1),
              Color(0xFF20B8C8),
              Color(0xFF087E9C),
            ],
          TerrainKind.shore => const [
              Color(0xFFE8DB88),
              Color(0xFFB5DB74),
              Color(0xFF56C67B),
            ],
          TerrainKind.land || TerrainKind.building => const [
              Color(0xFF57CB68),
              Color(0xFF50C765),
              Color(0xFF49BF61),
            ],
          TerrainKind.road || TerrainKind.pier => const [
              Color(0xFFFFF8D8),
              Color(0xFFE7DEB5),
            ],
          TerrainKind.fishingNode => const [
              Color(0xFF8EE35F),
              Color(0xFF46C968),
            ],
        },
      ).createShader(rect)
      ..style = PaintingStyle.fill;
  }

  void _drawPerspectiveRoadCells(
    Canvas canvas,
    Size size,
    List<TerrainTile> orderedTiles,
  ) {
    final roadTiles = orderedTiles
        .where((tile) =>
            tile.kind == TerrainKind.road || tile.kind == TerrainKind.pier)
        .toList();
    for (final tile in roadTiles) {
      final rect = _projectTileToPerspective(size, tile);
      if (rect == null) continue;
      final path = _terrainCellPathFromCamera(
        rect.inflate(rect.width * 0.14),
        tile,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF165B47).withValues(alpha: 0.2)
          ..style = PaintingStyle.fill
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawPath(
        path,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFBE2), Color(0xFFEADFB9)],
          ).createShader(rect)
          ..style = PaintingStyle.fill,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.46)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }
  }

  // Retained for the procedural fallback renderer.
  // ignore: unused_element
  void _drawGameTerrainZoneLayer(Canvas canvas, Size size) {
    if (terrainTiles.isEmpty) return;
    final visibleTiles = terrainTiles
        .where(
            (tile) => camera.isVisible(tile.centerLatLng, paddingMeters: 120))
        .toList(growable: false);
    for (final tile in visibleTiles) {
      if (tile.kind == TerrainKind.road ||
          tile.kind == TerrainKind.pier ||
          tile.kind == TerrainKind.fishingNode) {
        continue;
      }
      final seed = tile.row * 211 + tile.col * 157;
      if (tile.kind == TerrainKind.land && (tile.row + tile.col) % 3 == 1) {
        continue;
      }
      final point = _terrainZoneLatLngFromTile(tile, seed);
      if (!camera.isVisible(point, paddingMeters: 120)) continue;
      final projected = camera.project(point);
      if (!_isScreenDecorationVisible(projected, size)) continue;
      switch (tile.kind) {
        case TerrainKind.land:
          _drawGameGrassZone(canvas, projected, seed);
        case TerrainKind.water:
          _drawGameWaterZone(canvas, projected, seed);
        case TerrainKind.shore:
          _drawGameShoreZone(canvas, projected, seed);
        case TerrainKind.road:
        case TerrainKind.pier:
        case TerrainKind.fishingNode:
          break;
        case TerrainKind.building:
          break;
      }
    }
  }

  LatLng _terrainZoneLatLngFromTile(TerrainTile tile, int seed) {
    final eastMeters = (_detailNoise(seed) - 0.5) * 46;
    final northMeters = (_detailNoise(seed + 23) - 0.5) * 46;
    final metersPerDegreeLng =
        111320.0 * math.cos(camera.center.latitude * math.pi / 180);
    return LatLng(
      tile.centerLatLng.latitude + northMeters / 111320.0,
      tile.centerLatLng.longitude + eastMeters / metersPerDegreeLng,
    );
  }

  void _drawGameGrassZone(Canvas canvas, Offset center, int seed) {
    final width = 156 + _detailNoise(seed) * 92;
    final height = 92 + _detailNoise(seed + 7) * 60;
    final angle = (_detailNoise(seed + 17) - 0.5) * 0.68;
    final path = _gameTerrainZonePath(width, height, seed);
    final bounds = Rect.fromCenter(
      center: Offset.zero,
      width: width,
      height: height,
    );
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0x5534B95F),
            Color(0x2EE6FF83),
            Color(0x33177A4D),
          ],
          stops: [0, 0.58, 1],
        ).createShader(bounds)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFE9FF9C).withValues(alpha: 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
  }

  void _drawGameWaterZone(Canvas canvas, Offset center, int seed) {
    final width = 176 + _detailNoise(seed) * 104;
    final height = 96 + _detailNoise(seed + 7) * 62;
    final angle = (_detailNoise(seed + 17) - 0.5) * 0.5;
    final path = _gameTerrainZonePath(width, height, seed);
    final bounds = Rect.fromCenter(
      center: Offset.zero,
      width: width,
      height: height,
    );
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0x49B8FFF7),
            Color(0x3326C9D0),
            Color(0x26046F91),
          ],
        ).createShader(bounds)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
  }

  void _drawGameShoreZone(Canvas canvas, Offset center, int seed) {
    final width = 146 + _detailNoise(seed) * 88;
    final height = 78 + _detailNoise(seed + 7) * 54;
    final angle = (_detailNoise(seed + 17) - 0.5) * 0.6;
    final path = _gameTerrainZonePath(width, height, seed);
    final bounds = Rect.fromCenter(
      center: Offset.zero,
      width: width,
      height: height,
    );
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0x4DFFF1A8),
            Color(0x338EDB79),
            Color(0x2633A274),
          ],
        ).createShader(bounds)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFFFF7BE).withValues(alpha: 0.09)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.9
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
  }

  Path _gameTerrainZonePath(double width, double height, int seed) {
    final path = Path();
    const count = 8;
    for (var i = 0; i < count; i++) {
      final angle = -math.pi / 2 + i * math.pi * 2 / count;
      final noise = 0.86 + _detailNoise(seed + i * 19) * 0.22;
      final x = math.cos(angle) * width * 0.5 * noise;
      final y = math.sin(angle) * height * 0.5 * noise;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        final previousAngle = -math.pi / 2 + (i - 0.5) * math.pi * 2 / count;
        final controlNoise = 0.92 + _detailNoise(seed + i * 23) * 0.14;
        path.quadraticBezierTo(
          math.cos(previousAngle) * width * 0.54 * controlNoise,
          math.sin(previousAngle) * height * 0.54 * controlNoise,
          x,
          y,
        );
      }
    }
    final closingAngle = -math.pi / 2 + (count - 0.5) * math.pi * 2 / count;
    path.quadraticBezierTo(
      math.cos(closingAngle) * width * 0.54,
      math.sin(closingAngle) * height * 0.54,
      0,
      -height * 0.5 * (0.86 + _detailNoise(seed) * 0.22),
    );
    return path..close();
  }

  void _drawTerrainDetailLayer(Canvas canvas, Size size) {
    if (terrainTiles.isEmpty) return;
    final visibleTiles = terrainTiles
        .where((tile) => camera.isVisible(tile.centerLatLng, paddingMeters: 80))
        .toList(growable: false);
    for (final tile in visibleTiles) {
      if (tile.kind == TerrainKind.road ||
          tile.kind == TerrainKind.pier ||
          tile.kind == TerrainKind.fishingNode) {
        continue;
      }
      final rect = _projectTileToPerspective(size, tile);
      if (rect == null) continue;
      final path = _terrainCellPathFromCamera(rect, tile);
      canvas.save();
      canvas.clipPath(path);
      switch (tile.kind) {
        case TerrainKind.land:
          _drawLandDetailTufts(canvas, rect, tile.row, tile.col);
        case TerrainKind.shore:
          _drawShoreReedDetails(canvas, rect, tile.row, tile.col);
        case TerrainKind.water:
          _drawWaterSparkleDetails(canvas, rect, tile.row, tile.col);
        case TerrainKind.road:
        case TerrainKind.pier:
        case TerrainKind.fishingNode:
          break;
        case TerrainKind.building:
          break;
      }
      canvas.restore();
    }
  }

  void _drawReadableTerrainToneLayer(Canvas canvas, Size size) {
    if (terrainTiles.isEmpty) return;
    final visibleTiles = terrainTiles
        .where((tile) => camera.isVisible(tile.centerLatLng, paddingMeters: 80))
        .toList(growable: false);
    for (final tile in visibleTiles) {
      if (tile.kind == TerrainKind.road ||
          tile.kind == TerrainKind.pier ||
          tile.kind == TerrainKind.fishingNode) {
        continue;
      }
      final rect = _projectTileToPerspective(size, tile);
      if (rect == null) continue;
      final path = _terrainCellPathFromCamera(rect, tile);
      canvas.save();
      canvas.clipPath(path);
      switch (tile.kind) {
        case TerrainKind.land:
          _drawLowFrequencyGrassWash(canvas, rect, tile.row, tile.col);
        case TerrainKind.water:
          if (!_isOpenWaterReadableWashSuppressed(tile.kind)) {
            _drawReadableWaterWash(canvas, rect, tile.row, tile.col);
          }
        case TerrainKind.shore:
          _drawReadableShoreWash(canvas, rect, tile.row, tile.col);
        case TerrainKind.road:
        case TerrainKind.pier:
        case TerrainKind.fishingNode:
          break;
        case TerrainKind.building:
          break;
      }
      canvas.restore();
    }
  }

  // Retained for the procedural fallback renderer.
  // ignore: unused_element
  void _drawWorldTerrainWashLayer(Canvas canvas, Size size) {
    if (terrainTiles.isEmpty) return;
    final budget = _renderBudget;
    final visibleTiles = _budgetedTiles(
      terrainTiles
          .where(
              (tile) => camera.isVisible(tile.centerLatLng, paddingMeters: 80))
          .toList(growable: false),
      maxTiles: budget.maxWashTiles,
    );
    for (final tile in visibleTiles) {
      if (tile.kind == TerrainKind.road ||
          tile.kind == TerrainKind.pier ||
          tile.kind == TerrainKind.fishingNode) {
        continue;
      }
      final seedBase = tile.row * 89 + tile.col * 127;
      final patchCount = tile.kind == TerrainKind.land ? 1 : 2;
      for (var i = 0; i < patchCount; i++) {
        final point = _terrainWashLatLngFromTile(tile, seedBase + i * 31);
        if (!camera.isVisible(point, paddingMeters: 80)) continue;
        final projected = camera.project(point);
        if (!_isScreenDecorationVisible(projected, size)) continue;
        _drawWorldTerrainWashPatch(
          canvas,
          projected,
          tile.kind,
          seedBase + i * 31,
        );
      }
    }
  }

  LatLng _terrainWashLatLngFromTile(TerrainTile tile, int seed) {
    final eastMeters = (_detailNoise(seed) - 0.5) * 54;
    final northMeters = (_detailNoise(seed + 19) - 0.5) * 54;
    final metersPerDegreeLng =
        111320.0 * math.cos(camera.center.latitude * math.pi / 180);
    return LatLng(
      tile.centerLatLng.latitude + northMeters / 111320.0,
      tile.centerLatLng.longitude + eastMeters / metersPerDegreeLng,
    );
  }

  void _drawWorldTerrainWashPatch(
    Canvas canvas,
    Offset center,
    TerrainKind kind,
    int seed,
  ) {
    final width = 96 + _detailNoise(seed) * 62;
    final height = 70 + _detailNoise(seed + 7) * 54;
    final rect = Rect.fromCenter(center: center, width: width, height: height);
    final colors = switch (kind) {
      TerrainKind.land => [
          const Color(0xFFB5F76C).withValues(alpha: 0.1),
          const Color(0xFF37B966).withValues(alpha: 0.08),
          Colors.transparent,
        ],
      TerrainKind.water => [
          const Color(0xFFB9FFF8).withValues(alpha: 0.12),
          const Color(0xFF1DBBCD).withValues(alpha: 0.11),
          Colors.transparent,
        ],
      TerrainKind.shore => [
          const Color(0xFFFFF0A8).withValues(alpha: 0.12),
          const Color(0xFF8DDE8D).withValues(alpha: 0.08),
          Colors.transparent,
        ],
      TerrainKind.road ||
      TerrainKind.pier ||
      TerrainKind.fishingNode ||
      TerrainKind.building =>
        [
          Colors.transparent,
          Colors.transparent,
          Colors.transparent,
        ],
    };
    canvas.drawOval(
      rect,
      Paint()
        ..shader = RadialGradient(
          colors: colors,
          stops: const [0, 0.58, 1],
        ).createShader(rect)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
  }

  // Retained for the procedural fallback renderer.
  // ignore: unused_element
  void _drawWorldTextureVeilLayer(Canvas canvas, Size size) {
    if (terrainTiles.isEmpty) return;
    final budget = _renderBudget;
    final visibleTiles = _budgetedTiles(
      terrainTiles
          .where(
              (tile) => camera.isVisible(tile.centerLatLng, paddingMeters: 90))
          .toList(growable: false),
      maxTiles: budget.maxVeilTiles,
    );
    for (final tile in visibleTiles) {
      if (tile.kind == TerrainKind.road ||
          tile.kind == TerrainKind.pier ||
          tile.kind == TerrainKind.fishingNode) {
        continue;
      }
      final seedBase = tile.row * 149 + tile.col * 193;
      final patchTotal = tile.kind == TerrainKind.land ? 2 : 1;
      for (var i = 0; i < patchTotal; i++) {
        final point = _terrainVeilLatLngFromTile(tile, seedBase + i * 43);
        if (!camera.isVisible(point, paddingMeters: 90)) continue;
        final projected = camera.project(point);
        if (!_isScreenDecorationVisible(projected, size)) continue;
        switch (tile.kind) {
          case TerrainKind.land:
            _drawWorldGrassVeilPatch(canvas, projected, seedBase + i * 43);
          case TerrainKind.water:
            _drawWorldWaterVeilPatch(canvas, projected, seedBase + i * 43);
          case TerrainKind.shore:
            _drawWorldShoreVeilPatch(canvas, projected, seedBase + i * 43);
          case TerrainKind.road:
          case TerrainKind.pier:
          case TerrainKind.fishingNode:
            break;
          case TerrainKind.building:
            break;
        }
      }
    }
  }

  List<TerrainTile> _budgetedTiles(
    List<TerrainTile> tiles, {
    required int maxTiles,
  }) {
    if (tiles.length <= maxTiles) return tiles;
    final step = (tiles.length / maxTiles).ceil();
    return [
      for (var i = 0; i < tiles.length; i += step) tiles[i],
    ];
  }

  LatLng _terrainVeilLatLngFromTile(TerrainTile tile, int seed) {
    final eastMeters = (_detailNoise(seed) - 0.5) * 86;
    final northMeters = (_detailNoise(seed + 17) - 0.5) * 86;
    final metersPerDegreeLng =
        111320.0 * math.cos(camera.center.latitude * math.pi / 180);
    return LatLng(
      tile.centerLatLng.latitude + northMeters / 111320.0,
      tile.centerLatLng.longitude + eastMeters / metersPerDegreeLng,
    );
  }

  void _drawWorldGrassVeilPatch(Canvas canvas, Offset center, int seed) {
    final width = 148 + _detailNoise(seed) * 96;
    final height = 82 + _detailNoise(seed + 5) * 56;
    final angle = (_detailNoise(seed + 11) - 0.5) * 0.9;
    final rect =
        Rect.fromCenter(center: Offset.zero, width: width, height: height);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    canvas.drawOval(
      rect,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFD9FF85).withValues(alpha: 0.12),
            const Color(0xFF55D46D).withValues(alpha: 0.075),
            const Color(0xFF087046).withValues(alpha: 0.035),
            Colors.transparent,
          ],
          stops: const [0, 0.45, 0.78, 1],
        ).createShader(rect)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    final bladePaint = Paint()
      ..color = const Color(0xFFF1FF9A).withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 5; i++) {
      final localSeed = seed + i * 13;
      final x = -width * 0.42 + width * _detailNoise(localSeed);
      final y = -height * 0.34 + height * _detailNoise(localSeed + 3);
      final length = 8 + _detailNoise(localSeed + 7) * 12;
      final lean = (_detailNoise(localSeed + 9) - 0.5) * 8;
      canvas.drawLine(
          Offset(x, y + length * 0.34), Offset(x + lean, y), bladePaint);
    }
    canvas.restore();
  }

  void _drawWorldWaterVeilPatch(Canvas canvas, Offset center, int seed) {
    final width = 176 + _detailNoise(seed) * 110;
    final height = 92 + _detailNoise(seed + 5) * 64;
    final angle = (_detailNoise(seed + 11) - 0.5) * 0.56;
    final rect =
        Rect.fromCenter(center: Offset.zero, width: width, height: height);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    canvas.drawOval(
      rect,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFC9FFF8).withValues(alpha: 0.16),
            const Color(0xFF37D6D3).withValues(alpha: 0.095),
            const Color(0xFF077E9A).withValues(alpha: 0.04),
            Colors.transparent,
          ],
          stops: const [0, 0.48, 0.8, 1],
        ).createShader(rect)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    final ripplePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 4; i++) {
      final y = -height * 0.24 + i * height * 0.16;
      final x = -width * (0.34 - i * 0.03);
      final path = Path()
        ..moveTo(x, y)
        ..quadraticBezierTo(-width * 0.12, y - 5, width * 0.08, y + 1.5)
        ..quadraticBezierTo(width * 0.24, y + 7, width * 0.38, y - 1);
      canvas.drawPath(path, ripplePaint);
    }
    canvas.restore();
  }

  void _drawWorldShoreVeilPatch(Canvas canvas, Offset center, int seed) {
    final width = 132 + _detailNoise(seed) * 88;
    final height = 72 + _detailNoise(seed + 5) * 50;
    final angle = (_detailNoise(seed + 11) - 0.5) * 0.72;
    final rect =
        Rect.fromCenter(center: Offset.zero, width: width, height: height);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    canvas.drawOval(
      rect,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFF2A8).withValues(alpha: 0.13),
            const Color(0xFFA2E681).withValues(alpha: 0.08),
            const Color(0xFF1AA073).withValues(alpha: 0.035),
            Colors.transparent,
          ],
          stops: const [0, 0.52, 0.82, 1],
        ).createShader(rect)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    final reedPaint = Paint()
      ..color = const Color(0xFFFFF4A0).withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 5; i++) {
      final localSeed = seed + i * 17;
      final x = -width * 0.38 + width * _detailNoise(localSeed);
      final y = -height * 0.18 + height * _detailNoise(localSeed + 3);
      final length = 8 + _detailNoise(localSeed + 7) * 10;
      final lean = (_detailNoise(localSeed + 9) - 0.5) * 7;
      canvas.drawLine(
          Offset(x, y + length * 0.3), Offset(x + lean, y), reedPaint);
    }
    canvas.restore();
  }

  void _drawLowFrequencyGrassWash(Canvas canvas, Rect rect, int row, int col) {
    final seed = row * 53 + col * 71;
    final washRect = Rect.fromCenter(
      center: rect.center,
      width: rect.width * 1.34,
      height: rect.height * 1.34,
    );
    canvas.drawOval(
      washRect,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF86EA72).withValues(alpha: 0.16),
            const Color(0xFF36B866).withValues(alpha: 0.06),
            Colors.transparent,
          ],
          stops: const [0, 0.58, 1],
        ).createShader(washRect),
    );
    for (var i = 0; i < 2; i++) {
      _drawLandColorPatch(canvas, rect, seed + i * 37);
    }
  }

  void _drawLandColorPatch(Canvas canvas, Rect rect, int seed) {
    final patchCenter = Offset(
      rect.left + rect.width * (0.16 + _detailNoise(seed) * 0.68),
      rect.top + rect.height * (0.18 + _detailNoise(seed + 11) * 0.58),
    );
    final radius = rect.longestSide * (0.26 + _detailNoise(seed + 23) * 0.18);
    final patchRect = Rect.fromCircle(center: patchCenter, radius: radius);
    final isLight = seed.isEven;
    canvas.drawOval(
      patchRect,
      Paint()
        ..shader = RadialGradient(
          colors: [
            (isLight ? const Color(0xFFC6FF81) : const Color(0xFF188E59))
                .withValues(alpha: isLight ? 0.055 : 0.045),
            Colors.transparent,
          ],
        ).createShader(patchRect),
    );
  }

  void _drawReadableWaterWash(Canvas canvas, Rect rect, int row, int col) {
    final waterRect = rect.inflate(rect.shortestSide * 0.05);
    canvas.drawRect(
      waterRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF7CECE4).withValues(alpha: 0.34),
            const Color(0xFF0AA8BD).withValues(alpha: 0.18),
            const Color(0xFF087896).withValues(alpha: 0.12),
          ],
        ).createShader(waterRect),
    );
    final shimmerPaint = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 2; i++) {
      final y = rect.top + rect.height * (0.32 + i * 0.24);
      final xOffset = _detailNoise(row * 17 + col * 13 + i) * rect.width * 0.16;
      canvas.drawLine(
        Offset(rect.left + rect.width * 0.18 + xOffset, y),
        Offset(
            rect.right - rect.width * 0.16 + xOffset, y + rect.height * 0.03),
        shimmerPaint,
      );
    }
  }

  void _drawReadableShoreWash(Canvas canvas, Rect rect, int row, int col) {
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFFFF2B4).withValues(alpha: 0.22),
            const Color(0xFF83D989).withValues(alpha: 0.1),
          ],
        ).createShader(rect),
    );
    final edgePaint = Paint()
      ..color = const Color(0xFFFFF4BF).withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    final y = rect.top + rect.height * (0.55 + _detailNoise(row + col) * 0.16);
    canvas.drawLine(
      Offset(rect.left + rect.width * 0.12, y),
      Offset(rect.right - rect.width * 0.08, y - rect.height * 0.06),
      edgePaint,
    );
  }

  void _drawTerrainBoundaryBlendLayer(Canvas canvas, Size size) {
    if (terrainTiles.isEmpty) return;
    final grid = {
      for (final tile in terrainTiles) '${tile.row}:${tile.col}': tile,
    };
    final visibleTiles = terrainTiles
        .where((tile) => camera.isVisible(tile.centerLatLng, paddingMeters: 80))
        .toList(growable: false);

    for (final tile in visibleTiles) {
      if (_isOverlayTerrain(tile.kind)) continue;
      final rect = _projectTileToPerspective(size, tile);
      if (rect == null) continue;
      final right = _terrainTileByGrid(grid, tile.row, tile.col + 1);
      final bottom = _terrainTileByGrid(grid, tile.row + 1, tile.col);
      if (right != null && !_isOverlayTerrain(right.kind)) {
        _drawTerrainBoundaryEdgeBlend(
          canvas,
          _terrainCellEdgePath(rect, tile, _TerrainCellEdge.right),
          tile.kind,
          right.kind,
          rect.shortestSide,
        );
      }
      if (bottom != null && !_isOverlayTerrain(bottom.kind)) {
        _drawTerrainBoundaryEdgeBlend(
          canvas,
          _terrainCellEdgePath(rect, tile, _TerrainCellEdge.bottom),
          tile.kind,
          bottom.kind,
          rect.shortestSide,
        );
      }
    }
  }

  // Retained for the procedural fallback renderer.
  // ignore: unused_element
  void _drawTerrainReliefLayer(Canvas canvas, Size size) {
    if (terrainTiles.isEmpty) return;
    final visibleTiles = terrainTiles
        .where((tile) => camera.isVisible(tile.centerLatLng, paddingMeters: 80))
        .toList(growable: false);

    for (final tile in visibleTiles) {
      if (_isOverlayTerrain(tile.kind)) continue;
      final rect = _projectTileToPerspective(size, tile);
      if (rect == null) continue;
      _drawTerrainCellRelief(canvas, size, tile, rect);
    }
  }

  // Retained for the procedural fallback renderer.
  // ignore: unused_element
  void _drawCoastalWaterSceneLayer(Canvas canvas, Size size) {
    if (terrainTiles.isEmpty) return;
    final visibleTiles = terrainTiles
        .where((tile) => camera.isVisible(tile.centerLatLng, paddingMeters: 80))
        .toList(growable: false);
    _drawOpenWaterSurfaceUnifier(canvas, size, visibleTiles);

    for (final tile in visibleTiles) {
      if (tile.kind != TerrainKind.water && tile.kind != TerrainKind.shore) {
        continue;
      }
      final rect = _projectTileToPerspective(size, tile);
      if (rect == null) continue;
      final path = _terrainCellPathFromCamera(rect, tile);
      canvas.save();
      canvas.clipPath(path);
      switch (tile.kind) {
        case TerrainKind.water:
          _drawWaterCurrentHighlights(canvas, rect, tile.row, tile.col);
        case TerrainKind.shore:
          _drawShoreFoamAndWetRocks(canvas, rect, tile.row, tile.col);
        case TerrainKind.land:
        case TerrainKind.road:
        case TerrainKind.pier:
        case TerrainKind.fishingNode:
          break;
        case TerrainKind.building:
          break;
      }
      canvas.restore();
    }
  }

  void _drawOpenWaterSurfaceUnifier(
    Canvas canvas,
    Size size,
    List<TerrainTile> visibleTiles,
  ) {
    final screenRect = Offset.zero & size;
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF9DFFF4).withValues(alpha: 0.16),
          const Color(0xFF16C8D5).withValues(alpha: 0.1),
          const Color(0xFF026F91).withValues(alpha: 0.18),
        ],
        stops: const [0, 0.46, 1],
      ).createShader(screenRect);
    for (final tile in visibleTiles) {
      if (tile.kind != TerrainKind.water) continue;
      final rect = _projectTileToPerspective(size, tile);
      if (rect == null) continue;
      canvas.drawPath(_terrainCellPathFromCamera(rect, tile), paint);
    }
  }

  void _drawWaterCurrentHighlights(Canvas canvas, Rect rect, int row, int col) {
    final seed = row * 131 + col * 173;
    if ((row + col) % 3 == 1) return;
    final glowRect = Rect.fromCenter(
      center: rect.center.translate(
        (_detailNoise(seed) - 0.5) * rect.width * 0.28,
        (_detailNoise(seed + 7) - 0.5) * rect.height * 0.22,
      ),
      width: rect.width * (0.74 + _detailNoise(seed + 11) * 0.24),
      height: rect.height * 0.34,
    );
    canvas.drawOval(
      glowRect,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFE9FFFA).withValues(alpha: 0.12),
            const Color(0xFF81F6EA).withValues(alpha: 0.055),
            Colors.transparent,
          ],
          stops: const [0, 0.48, 1],
        ).createShader(glowRect)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    for (var i = 0; i < 4; i++) {
      final localSeed = seed + i * 29;
      final y = rect.top + rect.height * (0.22 + i * 0.15);
      final startX =
          rect.left + rect.width * (0.08 + _detailNoise(localSeed) * 0.18);
      final endX =
          rect.right - rect.width * (0.12 + _detailNoise(localSeed + 5) * 0.2);
      final lift = (_detailNoise(localSeed + 9) - 0.5) * rect.height * 0.12;
      final path = Path()
        ..moveTo(startX, y)
        ..quadraticBezierTo(
          rect.center.dx,
          y + lift,
          endX,
          y + rect.height * (0.02 + _detailNoise(localSeed + 13) * 0.04),
        );
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.08 - i * 0.01)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.6),
      );
    }
  }

  void _drawShoreFoamAndWetRocks(Canvas canvas, Rect rect, int row, int col) {
    final seed = row * 181 + col * 97;
    final foamPaint = Paint()
      ..color = const Color(0xFFFFF8CF).withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 2; i++) {
      final y = rect.top + rect.height * (0.42 + i * 0.13);
      final path = Path()
        ..moveTo(rect.left + rect.width * 0.12, y)
        ..quadraticBezierTo(
          rect.center.dx +
              (_detailNoise(seed + i * 19) - 0.5) * rect.width * 0.16,
          y - rect.height * (0.06 + _detailNoise(seed + i * 23) * 0.06),
          rect.right - rect.width * 0.1,
          y + rect.height * 0.02,
        );
      canvas.drawPath(path, foamPaint);
    }

    for (var i = 0; i < 5; i++) {
      final localSeed = seed + i * 31;
      final center = Offset(
        rect.left + rect.width * (0.14 + _detailNoise(localSeed) * 0.72),
        rect.top + rect.height * (0.48 + _detailNoise(localSeed + 7) * 0.32),
      );
      final rockRect = Rect.fromCenter(
        center: center,
        width: rect.width * (0.045 + _detailNoise(localSeed + 11) * 0.04),
        height: rect.height * (0.035 + _detailNoise(localSeed + 17) * 0.035),
      );
      canvas.drawOval(
        rockRect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFEFE7B4), Color(0xFF4F7C68)],
          ).createShader(rockRect)
          ..style = PaintingStyle.fill,
      );
      canvas.drawOval(
        rockRect.translate(0, rockRect.height * 0.28),
        Paint()
          ..color = const Color(0xFF073E49).withValues(alpha: 0.14)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.4),
      );
    }
  }

  void _drawTerrainCellRelief(
    Canvas canvas,
    Size size,
    TerrainTile tile,
    Rect rect,
  ) {
    if (_isOpenWaterReliefSuppressed(tile.kind)) return;
    final path = _terrainCellPathFromCamera(rect, tile);
    final colors = _terrainReliefPaletteFor(tile.kind);
    final depth = (rect.center.dy / size.height).clamp(0.0, 1.0);
    final edgeWidth = (rect.shortestSide * 0.07).clamp(1.8, 4.8).toDouble();
    final edgeAlpha = 0.055 + depth * 0.035;

    canvas.save();
    canvas.clipPath(path);
    canvas.drawRect(
      rect.inflate(rect.shortestSide * 0.04),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors[0].withValues(alpha: 0.08),
            Colors.transparent,
            colors[1].withValues(alpha: 0.06 + depth * 0.025),
          ],
          stops: const [0, 0.52, 1],
        ).createShader(rect),
    );
    canvas.restore();

    final sideShadowPaint = Paint()
      ..color = colors[1].withValues(alpha: edgeAlpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = edgeWidth
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.4);
    canvas.drawPath(
      _terrainCellEdgePath(rect, tile, _TerrainCellEdge.right),
      sideShadowPaint,
    );
    canvas.drawPath(
      _terrainCellEdgePath(rect, tile, _TerrainCellEdge.bottom),
      sideShadowPaint,
    );
    canvas.drawPath(
      _terrainCellEdgePath(rect, tile, _TerrainCellEdge.top),
      Paint()
        ..color = colors[0].withValues(alpha: 0.11)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      _terrainCellEdgePath(rect, tile, _TerrainCellEdge.bottom),
      Paint()
        ..color = colors[2].withValues(alpha: 0.1 + depth * 0.04)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (edgeWidth * 0.72).clamp(1.4, 3.5)
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.8),
    );
  }

  bool _isOpenWaterReliefSuppressed(TerrainKind kind) {
    return kind == TerrainKind.water;
  }

  bool _isOpenWaterReadableWashSuppressed(TerrainKind kind) {
    return kind == TerrainKind.water;
  }

  bool _isOpenWaterTextureSuppressed(TerrainKind kind) {
    return kind == TerrainKind.water;
  }

  List<Color> _terrainReliefPaletteFor(TerrainKind kind) {
    return switch (kind) {
      TerrainKind.land || TerrainKind.building => const [
          Color(0xFFE6FF91),
          Color(0xFF0B6F48),
          Color(0xFF0C7A50),
        ],
      TerrainKind.shore => const [
          Color(0xFFFFF1A8),
          Color(0xFF5C9852),
          Color(0xFF7AA85D),
        ],
      TerrainKind.water => const [
          Color(0xFFCFFFF8),
          Color(0xFF035B7B),
          Color(0xFF047A9A),
        ],
      TerrainKind.road || TerrainKind.pier => const [
          Color(0xFFFFFFFF),
          Color(0xFF746D5F),
          Color(0xFF8B8168),
        ],
      TerrainKind.fishingNode => const [
          Color(0xFFE9FF94),
          Color(0xFF0B714F),
          Color(0xFF0E8056),
        ],
    };
  }

  TerrainTile? _terrainTileByGrid(
    Map<String, TerrainTile> grid,
    int row,
    int col,
  ) {
    return grid['$row:$col'];
  }

  bool _isOverlayTerrain(TerrainKind kind) {
    return kind == TerrainKind.road ||
        kind == TerrainKind.pier ||
        kind == TerrainKind.fishingNode;
  }

  Path _terrainCellEdgePath(
    Rect rect,
    TerrainTile tile,
    _TerrainCellEdge edge,
  ) {
    final isPerspective = tile.kind == TerrainKind.water ||
        tile.kind == TerrainKind.road ||
        tile.kind == TerrainKind.pier;
    final topInset = rect.width * (isPerspective ? 0.08 : 0.06);
    final sideInset = isPerspective ? 0.0 : rect.width * 0.025;
    final topLeft = Offset(rect.left + topInset, rect.top);
    final topRight = Offset(rect.right - topInset, rect.top);
    final bottomRight = Offset(rect.right - sideInset, rect.bottom);
    final bottomLeft = Offset(rect.left + sideInset, rect.bottom);
    final path = Path();

    switch (edge) {
      case _TerrainCellEdge.top:
        path
          ..moveTo(topLeft.dx, topLeft.dy)
          ..lineTo(topRight.dx, topRight.dy);
      case _TerrainCellEdge.right:
        path
          ..moveTo(topRight.dx, topRight.dy)
          ..lineTo(bottomRight.dx, bottomRight.dy);
      case _TerrainCellEdge.bottom:
        path
          ..moveTo(bottomLeft.dx, bottomLeft.dy)
          ..lineTo(bottomRight.dx, bottomRight.dy);
      case _TerrainCellEdge.left:
        path
          ..moveTo(topLeft.dx, topLeft.dy)
          ..lineTo(bottomLeft.dx, bottomLeft.dy);
    }
    return path;
  }

  void _drawTerrainBoundaryEdgeBlend(
    Canvas canvas,
    Path edgePath,
    TerrainKind current,
    TerrainKind neighbor,
    double tileSize,
  ) {
    if (current == neighbor) return;
    final baseColor = _boundaryBlendColorFor(current, neighbor);
    final width = tileSize * 0.28;
    canvas.drawPath(
      edgePath,
      Paint()
        ..color = baseColor.withValues(alpha: 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = width.clamp(7.0, 18.0)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawPath(
      edgePath,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.09)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (width * 0.32).clamp(2.0, 5.0)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  Color _boundaryBlendColorFor(TerrainKind a, TerrainKind b) {
    final hasWater = a == TerrainKind.water || b == TerrainKind.water;
    final hasShore = a == TerrainKind.shore || b == TerrainKind.shore;
    final hasLand = a == TerrainKind.land || b == TerrainKind.land;
    if (hasWater && hasShore) return const Color(0xFFBFF9E8);
    if (hasWater && hasLand) return const Color(0xFF8DE7C2);
    if (hasShore && hasLand) return const Color(0xFFDDF79A);
    if (hasLand) return const Color(0xFF7EE678);
    return const Color(0xFFC4FFF6);
  }

  void _drawWorldSeamFusionLayer(Canvas canvas, Size size) {
    if (!_renderBudget.enableVectorTransitions) return;
    for (final feature in terrainFeatures) {
      if (feature.kind == TerrainKind.fishingNode) continue;
      final path = _pathForFeature(feature);
      if (path == null) continue;
      if (feature.kind == TerrainKind.road) {
        _drawRoadVergeDetail(canvas, path);
      } else {
        _drawVectorTerrainTransition(canvas, path, feature.kind);
      }
    }
  }

  void _drawVectorTerrainTransition(
    Canvas canvas,
    Path path,
    TerrainKind kind,
  ) {
    final colors = _vectorTransitionColors(kind);
    if (colors == null) return;
    final baseWidth = switch (kind) {
      TerrainKind.water => 18.0,
      TerrainKind.shore => 16.0,
      TerrainKind.land || TerrainKind.building => 13.0,
      TerrainKind.pier => 10.0,
      TerrainKind.road || TerrainKind.fishingNode => 0.0,
    };
    canvas.drawPath(
      path,
      Paint()
        ..color = colors.$1
        ..style = PaintingStyle.stroke
        ..strokeWidth = baseWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = colors.$2
        ..style = PaintingStyle.stroke
        ..strokeWidth = baseWidth * 0.36
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  (Color, Color)? _vectorTransitionColors(TerrainKind kind) {
    return switch (kind) {
      TerrainKind.water => (
          const Color(0xFF8DFFF4).withValues(alpha: 0.12),
          const Color(0xFFFFFFFF).withValues(alpha: 0.07),
        ),
      TerrainKind.shore => (
          const Color(0xFFFFEFA8).withValues(alpha: 0.14),
          const Color(0xFF96E188).withValues(alpha: 0.08),
        ),
      TerrainKind.land || TerrainKind.building => (
          const Color(0xFFB9FF79).withValues(alpha: 0.09),
          const Color(0xFF2FB66C).withValues(alpha: 0.06),
        ),
      TerrainKind.pier => (
          const Color(0xFF174751).withValues(alpha: 0.1),
          const Color(0xFFE7FFF8).withValues(alpha: 0.07),
        ),
      TerrainKind.road || TerrainKind.fishingNode => null,
    };
  }

  void _drawRoadVergeDetail(Canvas canvas, Path path) {
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFC7FF77).withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 30
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawPath(
      path.shift(const Offset(0, 2.8)),
      Paint()
        ..color = const Color(0xFF06343A).withValues(alpha: 0.09)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 26
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    final grassPaint = Paint()
      ..color = const Color(0xFFE9FF90).withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    for (final metric in path.computeMetrics()) {
      if (metric.length < 24) continue;
      var distance = 10.0;
      var index = 0;
      while (distance < metric.length) {
        final tangent = metric.getTangentForOffset(distance);
        if (tangent == null) break;
        final normal = Offset(-tangent.vector.dy, tangent.vector.dx);
        final side = index.isEven ? 1.0 : -1.0;
        final root = tangent.position + normal * side * 11.0;
        final tip = root - tangent.vector * 2.0 - normal * side * 4.0;
        canvas.drawLine(root, tip, grassPaint);
        distance += 19 + (index % 3) * 4;
        index++;
      }
    }
  }

  void _drawImagegenInspiredMapLayer(Canvas canvas, Size size) {
    if (terrainTiles.isEmpty) return;
    if (!_renderBudget.enableDecorativeOverlays) return;
    final visibleTiles = terrainTiles
        .where((tile) => camera.isVisible(tile.centerLatLng, paddingMeters: 80))
        .toList(growable: false);
    _drawTreeCanopyClusters(canvas, size, visibleTiles);
    _drawShoreRockDetails(canvas, size, visibleTiles);
  }

  // Retained for the procedural fallback renderer.
  // ignore: unused_element
  void _drawWorldDecorationLayer(Canvas canvas, Size size) {
    if (terrainTiles.isEmpty) return;
    if (!_renderBudget.enableDecorativeOverlays) return;
    final visibleTiles = terrainTiles
        .where((tile) => camera.isVisible(tile.centerLatLng, paddingMeters: 80))
        .toList(growable: false);
    for (final tile in visibleTiles) {
      if (tile.kind != TerrainKind.land && tile.kind != TerrainKind.shore) {
        continue;
      }
      final seedBase = tile.row * 101 + tile.col * 79;
      if (tile.kind == TerrainKind.land) {
        if ((tile.row + tile.col) % 2 != 0) continue;
        for (var i = 0; i < 1; i++) {
          final point = _decorLatLngFromTile(tile, seedBase + i * 17);
          if (!camera.isVisible(point, paddingMeters: 60)) continue;
          final projected = camera.project(point);
          if (!_isScreenDecorationVisible(projected, size)) continue;
          _drawWorldGrassCluster(canvas, projected, seedBase + i * 17);
        }
        if ((tile.row * 3 + tile.col * 5) % 11 == 0) {
          final point = _decorLatLngFromTile(tile, seedBase + 47);
          if (!camera.isVisible(point, paddingMeters: 60)) continue;
          final projected = camera.project(point);
          if (_isScreenDecorationVisible(projected, size)) {
            _drawWorldTreeCluster(canvas, projected, seedBase + 47);
          }
        }
      } else if ((tile.row + tile.col) % 3 == 0) {
        final point = _decorLatLngFromTile(tile, seedBase + 23);
        if (!camera.isVisible(point, paddingMeters: 60)) continue;
        final projected = camera.project(point);
        if (_isScreenDecorationVisible(projected, size)) {
          _drawWorldReedCluster(canvas, projected, seedBase + 23);
        }
      }
    }
  }

  LatLng _decorLatLngFromTile(TerrainTile tile, int seed) {
    final eastMeters = (_detailNoise(seed) - 0.5) * 34;
    final northMeters = (_detailNoise(seed + 13) - 0.5) * 34;
    final metersPerDegreeLng =
        111320.0 * math.cos(camera.center.latitude * math.pi / 180);
    return LatLng(
      tile.centerLatLng.latitude + northMeters / 111320.0,
      tile.centerLatLng.longitude + eastMeters / metersPerDegreeLng,
    );
  }

  bool _isScreenDecorationVisible(Offset point, Size size) {
    return point.dx >= -32 &&
        point.dx <= size.width + 32 &&
        point.dy >= 74 &&
        point.dy <= size.height - 92;
  }

  void _drawWorldGrassCluster(Canvas canvas, Offset center, int seed) {
    final scale = 0.76 + _detailNoise(seed + 3) * 0.55;
    final shadowPaint = Paint()
      ..color = const Color(0xFF0D6A43).withValues(alpha: 0.08)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawOval(
      Rect.fromCenter(
          center: center.translate(0, 4), width: 20 * scale, height: 8 * scale),
      shadowPaint,
    );
    final bladePaint = Paint()
      ..color = const Color(0xFFE7FF91).withValues(alpha: 0.24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1 * scale
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 4; i++) {
      final x = center.dx + (i - 2) * 3.4 * scale;
      final height = (7 + _detailNoise(seed + i * 5) * 7) * scale;
      final lean = (_detailNoise(seed + i * 7) - 0.5) * 5 * scale;
      canvas.drawLine(
        Offset(x, center.dy + 2 * scale),
        Offset(x + lean, center.dy - height),
        bladePaint,
      );
    }
    if (seed % 4 == 0) {
      canvas.drawCircle(
        center.translate(4 * scale, -8 * scale),
        2.2 * scale,
        Paint()..color = _flowerColor(seed).withValues(alpha: 0.5),
      );
    }
  }

  void _drawWorldTreeCluster(Canvas canvas, Offset center, int seed) {
    final radius = 7.0 + _detailNoise(seed) * 4;
    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(0, radius * 0.76),
        width: radius * 3.0,
        height: radius * 0.9,
      ),
      Paint()
        ..color = const Color(0xFF084332).withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    final trunkPaint = Paint()
      ..color = const Color(0xFF6E8D42).withValues(alpha: 0.32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      center.translate(0, radius * 0.5),
      center.translate(0, -radius * 0.45),
      trunkPaint,
    );
    final paints = [
      Paint()..color = const Color(0xFF50C966).withValues(alpha: 0.62),
      Paint()..color = const Color(0xFF83EA70).withValues(alpha: 0.62),
      Paint()..color = const Color(0xFF2EA85A).withValues(alpha: 0.54),
    ];
    for (var i = 0; i < 3; i++) {
      final bubble = center.translate(
        math.cos(i * math.pi * 2 / 3) * radius * 0.46,
        -radius * 0.48 + math.sin(i * math.pi * 2 / 3) * radius * 0.32,
      );
      canvas.drawCircle(bubble, radius * (0.66 + i * 0.08), paints[i]);
    }
  }

  void _drawWorldReedCluster(Canvas canvas, Offset center, int seed) {
    final reedPaint = Paint()
      ..color = const Color(0xFFFFF1A0).withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final base =
          center.translate((i - 1.5) * 3.2, _detailNoise(seed + i) * 4);
      final height = 9 + _detailNoise(seed + i * 9) * 7;
      final lean = (_detailNoise(seed + i * 11) - 0.5) * 5;
      canvas.drawLine(base, base.translate(lean, -height), reedPaint);
    }
  }

  void _drawTreeCanopyClusters(
    Canvas canvas,
    Size size,
    List<TerrainTile> visibleTiles,
  ) {
    final landTiles = visibleTiles
        .where((tile) => tile.kind == TerrainKind.land)
        .toList(growable: false);
    for (final tile in landTiles) {
      if ((tile.row * 5 + tile.col * 3) % 13 > 1) continue;
      final rect = _projectTileToPerspective(size, tile);
      if (rect == null) continue;
      final center = rect.center.translate(
        (0.5 - _detailNoise(tile.row * 31 + tile.col)) * rect.width * 0.5,
        (0.5 - _detailNoise(tile.col * 29 + tile.row)) * rect.height * 0.5,
      );
      final radius = rect.shortestSide * (0.06 + _detailNoise(tile.row) * 0.03);
      final trunkPaint = Paint()
        ..color = const Color(0xFF6B8B45).withValues(alpha: 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (radius * 0.24).clamp(1.2, 2.4)
        ..strokeCap = StrokeCap.round;
      final shadowPaint = Paint()
        ..color = const Color(0xFF073B2E).withValues(alpha: 0.18)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawOval(
        Rect.fromCenter(
          center: center.translate(0, radius * 0.62),
          width: radius * 2.5,
          height: radius * 0.92,
        ),
        shadowPaint,
      );
      canvas.drawLine(
        center.translate(0, radius * 0.45),
        center.translate(0, -radius * 0.4),
        trunkPaint,
      );
      final canopyColors = [
        const Color(0xFF69D96C).withValues(alpha: 0.72),
        const Color(0xFF95EF73).withValues(alpha: 0.7),
        const Color(0xFF38B85F).withValues(alpha: 0.64),
      ];
      for (var i = 0; i < 3; i++) {
        final bubble = center.translate(
          math.cos(i * math.pi * 2 / 3) * radius * 0.5,
          -radius * 0.46 + math.sin(i * math.pi * 2 / 3) * radius * 0.32,
        );
        canvas.drawCircle(
          bubble,
          radius * (0.7 + i * 0.08),
          Paint()..color = canopyColors[i],
        );
      }
      canvas.drawCircle(
        center.translate(-radius * 0.18, -radius * 0.78),
        radius * 0.38,
        Paint()..color = const Color(0xFFE8FFD2).withValues(alpha: 0.22),
      );
    }
  }

  void _drawShoreRockDetails(
    Canvas canvas,
    Size size,
    List<TerrainTile> visibleTiles,
  ) {
    final shoreTiles = visibleTiles
        .where((tile) => tile.kind == TerrainKind.shore)
        .toList(growable: false);
    final rockPaint = Paint()
      ..color = const Color(0xFFF3E4B2).withValues(alpha: 0.52)
      ..style = PaintingStyle.fill;
    final darkRockPaint = Paint()
      ..color = const Color(0xFF62836D).withValues(alpha: 0.32)
      ..style = PaintingStyle.fill;
    for (final tile in shoreTiles) {
      final rect = _projectTileToPerspective(size, tile);
      if (rect == null) continue;
      for (var i = 0; i < 3; i++) {
        final seed = tile.row * 23 + tile.col * 41 + i * 5;
        final center = Offset(
          rect.left + rect.width * (0.18 + _detailNoise(seed) * 0.64),
          rect.top + rect.height * (0.52 + _detailNoise(seed + 3) * 0.34),
        );
        final radius =
            rect.shortestSide * (0.025 + _detailNoise(seed + 9) * 0.02);
        canvas.drawOval(
          Rect.fromCenter(
            center: center,
            width: radius * 2.4,
            height: radius * 1.35,
          ),
          i.isEven ? rockPaint : darkRockPaint,
        );
      }
    }
  }

  void _drawLandDetailTufts(Canvas canvas, Rect rect, int row, int col) {
    final tuftPaint = Paint()
      ..color = const Color(0xFFE3FF8F).withValues(alpha: 0.36)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (rect.width * 0.022).clamp(0.8, 1.55)
      ..strokeCap = StrokeCap.round;
    final shadowPaint = Paint()
      ..color = const Color(0xFF0A5C3D).withValues(alpha: 0.16)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    for (var i = 0; i < 3; i++) {
      final seed = row * 37 + col * 17 + i * 11;
      final x = rect.left + rect.width * (0.18 + _detailNoise(seed) * 0.64);
      final y = rect.top + rect.height * (0.2 + _detailNoise(seed + 5) * 0.62);
      final base = Offset(x, y);
      final size = rect.shortestSide * (0.07 + _detailNoise(seed + 9) * 0.04);
      canvas.drawOval(
        Rect.fromCenter(
          center: base.translate(0, size * 0.32),
          width: size * 1.9,
          height: size * 0.72,
        ),
        shadowPaint,
      );
      canvas.drawLine(base, base.translate(-size * 0.38, -size), tuftPaint);
      canvas.drawLine(base, base.translate(size * 0.1, -size * 1.1), tuftPaint);
      canvas.drawLine(
          base, base.translate(size * 0.42, -size * 0.72), tuftPaint);
      if ((row + col + i) % 5 == 0) {
        final flowerPaint = Paint()
          ..color = _flowerColor(seed)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(
          base.translate(size * 0.18, -size * 0.86),
          (size * 0.24).clamp(1.6, 3.2),
          flowerPaint,
        );
      }
    }
  }

  void _drawShoreReedDetails(Canvas canvas, Rect rect, int row, int col) {
    final reedPaint = Paint()
      ..color = const Color(0xFFEFFF9B).withValues(alpha: 0.32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (rect.width * 0.014).clamp(0.45, 1.0)
      ..strokeCap = StrokeCap.round;
    final basePaint = Paint()
      ..color = const Color(0xFF12684B).withValues(alpha: 0.14)
      ..style = PaintingStyle.fill;

    for (var i = 0; i < 5; i++) {
      final seed = row * 43 + col * 19 + i * 13;
      final x = rect.left + rect.width * (0.12 + _detailNoise(seed) * 0.76);
      final y = rect.top + rect.height * (0.3 + _detailNoise(seed + 7) * 0.56);
      final height = rect.shortestSide * (0.08 + _detailNoise(seed + 3) * 0.05);
      final lean = (0.5 - _detailNoise(seed + 11)) * rect.width * 0.05;
      canvas.drawCircle(Offset(x, y + height * 0.18), height * 0.28, basePaint);
      canvas.drawLine(
        Offset(x, y),
        Offset(x + lean, y - height),
        reedPaint,
      );
    }
  }

  void _drawWaterSparkleDetails(Canvas canvas, Rect rect, int row, int col) {
    final sparklePaint = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (rect.width * 0.012).clamp(0.45, 1.1)
      ..strokeCap = StrokeCap.round;
    final crossSparklePaint = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (rect.width * 0.012).clamp(0.45, 1.1)
      ..strokeCap = StrokeCap.round;
    final glowPaint = Paint()
      ..color = const Color(0xFFB8FFFA).withValues(alpha: 0.1)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    for (var i = 0; i < 3; i++) {
      final seed = row * 29 + col * 31 + i * 17;
      final center = Offset(
        rect.left + rect.width * (0.16 + _detailNoise(seed) * 0.68),
        rect.top + rect.height * (0.22 + _detailNoise(seed + 4) * 0.58),
      );
      final width = rect.width * (0.08 + _detailNoise(seed + 8) * 0.06);
      canvas.drawOval(
        Rect.fromCenter(
          center: center,
          width: width * 1.7,
          height: width * 0.6,
        ),
        glowPaint,
      );
      canvas.drawLine(
        center.translate(-width * 0.5, 0),
        center.translate(width * 0.5, 0),
        sparklePaint,
      );
      if ((row + col + i) % 3 == 0) {
        canvas.drawLine(
          center.translate(0, -width * 0.26),
          center.translate(0, width * 0.26),
          crossSparklePaint,
        );
      }
    }
  }

  double _detailNoise(int seed) {
    final value = math.sin(seed * 12.9898 + 78.233) * 43758.5453;
    return value - value.floorToDouble();
  }

  Color _flowerColor(int seed) {
    return switch (seed.abs() % 4) {
      0 => const Color(0xFFFFF36C).withValues(alpha: 0.72),
      1 => const Color(0xFFFFFFFF).withValues(alpha: 0.62),
      2 => const Color(0xFFFF9FCB).withValues(alpha: 0.58),
      _ => const Color(0xFFB8F7FF).withValues(alpha: 0.56),
    };
  }

  void _drawPerspectiveCellTexture(
    Canvas canvas,
    Rect rect,
    TerrainKind kind,
    int variant,
  ) {
    switch (kind) {
      case TerrainKind.water:
        if (!_isOpenWaterTextureSuppressed(kind)) {
          _drawWaterTileRipples(
            canvas,
            rect.center,
            rect.width,
            rect.height,
            variant,
          );
        }
      case TerrainKind.land:
        _drawSeedreamLandMicroTile(
          canvas,
          rect,
          variant,
        );
      case TerrainKind.shore:
        _drawShoreGrassMicroTile(canvas, rect, variant);
        _drawShoreTilePebbles(
            canvas, rect.center, rect.width, rect.height, variant);
      case TerrainKind.road:
      case TerrainKind.pier:
        _drawTileLightBreakup(
          canvas,
          rect.center,
          rect.width,
          rect.height,
          variant,
          color: const Color(0xFFFFFFFF).withValues(alpha: 0.12),
        );
      case TerrainKind.fishingNode:
        break;
      case TerrainKind.building:
        break;
    }
  }

  void _drawSeedreamLandMicroTile(Canvas canvas, Rect rect, int variant) {
    final baseImage =
        texturePack.grassMicro ?? texturePack.grassMid ?? texturePack.land;
    if (baseImage == null) return;
    const tileScale = 0.082;
    final matrix = Matrix4.identity()
      ..translateByDouble(
        -camera.project(camera.center).dx * 0.18,
        -camera.project(camera.center).dy * 0.18,
        0,
        1,
      )
      ..scaleByDouble(tileScale, tileScale, 1, 1);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.ImageShader(
          baseImage,
          ui.TileMode.repeated,
          ui.TileMode.repeated,
          matrix.storage,
        )
        ..colorFilter = ColorFilter.mode(
          const Color(0xFFD6FFB0).withValues(alpha: 0.28),
          BlendMode.modulate,
        )
        ..style = PaintingStyle.fill,
    );
    final toneImage = _landMicroImageForVariant(variant);
    if (toneImage == null || identical(toneImage, baseImage)) return;
    final toneAlpha = switch (variant.abs() % 6) {
      0 => 0.02,
      1 => 0.026,
      2 => 0.018,
      3 => 0.03,
      4 => 0.024,
      _ => 0.016,
    };
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.ImageShader(
          toneImage,
          ui.TileMode.repeated,
          ui.TileMode.repeated,
          matrix.storage,
        )
        ..colorFilter = ColorFilter.mode(
          Color.fromRGBO(255, 255, 255, toneAlpha),
          BlendMode.modulate,
        )
        ..style = PaintingStyle.fill,
    );
  }

  ui.Image? _landMicroImageForVariant(int variant) {
    return texturePack.landMicroImageForVariant(variant);
  }

  void _drawShoreGrassMicroTile(Canvas canvas, Rect rect, int variant) {
    final image =
        texturePack.shoreGrass ?? texturePack.groundMoss ?? texturePack.shore;
    if (image == null) return;
    const tileScale = 0.075;
    final matrix = Matrix4.identity()
      ..translateByDouble((variant % 5) * 41.0, (variant % 7) * 31.0, 0, 1)
      ..scaleByDouble(tileScale, tileScale, 1, 1);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.ImageShader(
          image,
          ui.TileMode.repeated,
          ui.TileMode.repeated,
          matrix.storage,
        )
        ..colorFilter = ColorFilter.mode(
          const Color(0xFFFFF0B6).withValues(alpha: 0.62),
          BlendMode.modulate,
        )
        ..style = PaintingStyle.fill,
    );
  }

  Color _cellEdgeColor(TerrainKind kind) {
    return switch (kind) {
      TerrainKind.water => const Color(0xFFD8FFFB).withValues(alpha: 0.1),
      TerrainKind.shore => const Color(0xFFFFFFC8).withValues(alpha: 0.18),
      TerrainKind.land || TerrainKind.building => Colors.transparent,
      TerrainKind.road ||
      TerrainKind.pier =>
        const Color(0xFFFFFFFF).withValues(alpha: 0.3),
      TerrainKind.fishingNode => Colors.transparent,
    };
  }

  // ignore: unused_element
  void _drawFallbackTileLayer(Canvas canvas, Size size) {
    if (terrainTiles.isEmpty) return;
    final tileWidth = camera.viewportSize.shortestSide / 7.2;
    final tileHeight = camera.viewportSize.shortestSide / 10.5;
    final projectedTiles = [
      for (final tile in terrainTiles)
        if (camera.isVisible(tile.centerLatLng, paddingMeters: 80))
          _ProjectedTerrainTile(tile, camera.project(tile.centerLatLng)),
    ];

    _drawSoftTerrainTiles(
      canvas,
      projectedTiles
          .where((tile) =>
              tile.data.kind == TerrainKind.land ||
              tile.data.kind == TerrainKind.shore)
          .toList(),
      tileWidth,
      tileHeight,
    );
    if (!terrainFeatures.any((feature) => feature.kind == TerrainKind.road)) {
      _drawFallbackRoads(
        canvas,
        projectedTiles
            .where((tile) => tile.data.kind == TerrainKind.road)
            .toList(),
        tileWidth,
      );
    }
    _drawFallbackPiers(
      canvas,
      projectedTiles
          .where((tile) => tile.data.kind == TerrainKind.pier)
          .toList(),
      tileWidth,
      tileHeight,
    );
  }

  // Retained for the procedural fallback renderer.
  // ignore: unused_element
  void _drawSeaLayer(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final waterPaint = _texturedFillPaint(
      TerrainKind.water,
      rect,
      fallbackColors: const [
        Color(0xFF6BE5E0),
        Color(0xFF28B9CC),
        Color(0xFF1D9DB5),
        Color(0xFF147B93),
      ],
      textureScale: 1.15,
    );
    canvas.drawRect(rect, waterPaint);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF8EFFF7).withValues(alpha: 0.16),
            Colors.transparent,
            const Color(0xFF063F54).withValues(alpha: 0.34),
          ],
          stops: const [0, 0.52, 1],
        ).createShader(rect),
    );

    for (final feature in terrainFeatures) {
      if (feature.kind != TerrainKind.water) continue;
      final path = _pathForFeature(feature);
      if (path == null) continue;
      if (feature.isClosed) {
        canvas.drawPath(
          path,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF7AF5EF).withValues(alpha: 0.18),
                const Color(0xFF036C8C).withValues(alpha: 0.42),
              ],
            ).createShader(path.getBounds())
            ..style = PaintingStyle.fill,
        );
      }
    }

    final wavePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.13)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 16; i++) {
      final y = size.height * (0.07 + i * 0.057);
      final xShift = (i.isEven ? -0.12 : -0.02) * size.width;
      final path = Path()
        ..moveTo(xShift, y)
        ..cubicTo(
          size.width * 0.18,
          y - 13,
          size.width * 0.38,
          y + 16,
          size.width * 0.64,
          y - 3,
        )
        ..quadraticBezierTo(
          size.width * 0.83,
          y - 18,
          size.width * 1.14,
          y + 4,
        );
      canvas.drawPath(path, wavePaint);
    }
  }

  // ignore: unused_element
  void _drawTileMeshLayer(Canvas canvas, Size size) {
    if (terrainTiles.isEmpty) return;
    final tileWidth = camera.viewportSize.shortestSide / 7.2;
    final tileHeight = camera.viewportSize.shortestSide / 10.5;
    for (final tile in terrainTiles) {
      if (!camera.isVisible(tile.centerLatLng, paddingMeters: 80)) continue;
      final center = camera.project(tile.centerLatLng);
      _drawTerrainTileSeam(
        canvas,
        center: center,
        width: tileWidth,
        height: tileHeight,
        kind: tile.kind,
      );
    }
  }

  // ignore: unused_element
  void _drawTerrainTextureLayer(Canvas canvas, Size size) {
    if (terrainTiles.isEmpty) return;
    final tileWidth = camera.viewportSize.shortestSide / 7.2;
    final tileHeight = camera.viewportSize.shortestSide / 10.5;
    for (var i = 0; i < terrainTiles.length; i++) {
      final tile = terrainTiles[i];
      if (!camera.isVisible(tile.centerLatLng, paddingMeters: 80)) continue;
      if (tile.kind == TerrainKind.fishingNode) continue;
      _drawTerrainTileTexture(
        canvas,
        center: camera.project(tile.centerLatLng),
        width: tileWidth,
        height: tileHeight,
        kind: tile.kind,
        variant: i,
      );
    }
  }

  void _drawTerrainTileTexture(
    Canvas canvas, {
    required Offset center,
    required double width,
    required double height,
    required TerrainKind kind,
    required int variant,
  }) {
    final path = _diamondPath(center, width, height);
    canvas.save();
    canvas.clipPath(path);
    switch (kind) {
      case TerrainKind.water:
        _drawWaterTileRipples(canvas, center, width, height, variant);
      case TerrainKind.land:
        _drawLandTileBrush(canvas, center, width, height, variant);
      case TerrainKind.shore:
        _drawShoreTilePebbles(canvas, center, width, height, variant);
      case TerrainKind.road:
      case TerrainKind.pier:
        _drawTileLightBreakup(
          canvas,
          center,
          width,
          height,
          variant,
          color: const Color(0xFFFFFFFF).withValues(alpha: 0.08),
        );
      case TerrainKind.fishingNode:
        break;
      case TerrainKind.building:
        break;
    }
    canvas.restore();
  }

  void _drawWaterTileRipples(
    Canvas canvas,
    Offset center,
    double width,
    double height,
    int variant,
  ) {
    _drawTileLightBreakup(
      canvas,
      center,
      width,
      height,
      variant,
      color: const Color(0xFFFFFFFF).withValues(alpha: 0.08),
    );
    final ripplePaint = Paint()
      ..color = const Color(0xFFD8FFFB).withValues(alpha: 0.17)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.05
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 4; i++) {
      final y =
          center.dy - height * 0.26 + i * height * 0.17 + (variant % 3) * 1.7;
      final startX = center.dx - width * (0.34 - i * 0.03);
      final path = Path()
        ..moveTo(startX, y)
        ..quadraticBezierTo(
          center.dx - width * 0.12,
          y - 4 - (variant % 2) * 1.6,
          center.dx + width * 0.08,
          y + 1.5,
        )
        ..quadraticBezierTo(
          center.dx + width * 0.24,
          y + 6,
          center.dx + width * 0.36,
          y - 1,
        );
      canvas.drawPath(path, ripplePaint);
    }
  }

  void _drawLandTileBrush(
    Canvas canvas,
    Offset center,
    double width,
    double height,
    int variant,
  ) {
    _drawTileLightBreakup(
      canvas,
      center,
      width,
      height,
      variant,
      color: const Color(0xFFF1FF9E).withValues(alpha: 0.11),
    );
    final grassPaint = Paint()
      ..color = const Color(0xFFE5FF9A).withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 7; i++) {
      final x = center.dx - width * 0.36 + i * width * 0.12;
      final y = center.dy - height * 0.2 + ((i + variant) % 4) * height * 0.11;
      canvas.drawLine(
        Offset(x, y + height * 0.12),
        Offset(x + width * 0.08, y - height * 0.08),
        grassPaint,
      );
    }
  }

  void _drawShoreTilePebbles(
    Canvas canvas,
    Offset center,
    double width,
    double height,
    int variant,
  ) {
    _drawTileLightBreakup(
      canvas,
      center,
      width,
      height,
      variant,
      color: const Color(0xFFFFE89A).withValues(alpha: 0.16),
    );
    final pebblePaint = Paint()
      ..color = const Color(0xFFFFF1B5).withValues(alpha: 0.24)
      ..style = PaintingStyle.fill;
    for (var i = 0; i < 6; i++) {
      final x = center.dx - width * 0.28 + i * width * 0.11;
      final y = center.dy + (((i * 5 + variant) % 7) - 3) * height * 0.045;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, y),
          width: 4 + (i % 3) * 1.5,
          height: 2.5 + ((i + variant) % 2) * 1.3,
        ),
        pebblePaint,
      );
    }
  }

  void _drawTileLightBreakup(
    Canvas canvas,
    Offset center,
    double width,
    double height,
    int variant, {
    required Color color,
  }) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final x = center.dx - width * 0.38 + i * width * 0.24;
      final y = center.dy - height * 0.24 + ((variant + i) % 4) * height * 0.14;
      canvas.drawLine(
        Offset(x, y),
        Offset(x + width * 0.24, y + height * 0.11),
        paint,
      );
    }
  }

  void _drawTerrainTileSeam(
    Canvas canvas, {
    required Offset center,
    required double width,
    required double height,
    required TerrainKind kind,
  }) {
    if (kind == TerrainKind.fishingNode) return;
    final path = _diamondPath(center, width, height);
    final isWater = kind == TerrainKind.water;
    final isRoad = kind == TerrainKind.road || kind == TerrainKind.pier;
    final lineColor = isRoad
        ? const Color(0xFF062E38).withValues(alpha: 0.2)
        : isWater
            ? const Color(0xFFB8FFF7).withValues(alpha: 0.08)
            : const Color(0xFFE8FFB8).withValues(alpha: 0.14);
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = isRoad ? 0.9 : 0.7
        ..strokeJoin = StrokeJoin.round,
    );
  }

  Path _diamondPath(Offset center, double width, double height) {
    return Path()
      ..moveTo(center.dx, center.dy - height * 0.5)
      ..lineTo(center.dx + width * 0.5, center.dy)
      ..lineTo(center.dx, center.dy + height * 0.5)
      ..lineTo(center.dx - width * 0.5, center.dy)
      ..close();
  }

  void _drawLandLayer(Canvas canvas, Size size) {
    for (final feature in terrainFeatures) {
      if (feature.kind != TerrainKind.land &&
          feature.kind != TerrainKind.shore) {
        continue;
      }
      final path = _pathForFeature(feature);
      if (path == null) continue;
      if (feature.isClosed) {
        canvas.drawPath(
          path,
          _texturedFillPaint(
            feature.kind,
            path.getBounds(),
            fallbackColors: feature.kind == TerrainKind.shore
                ? const [
                    Color(0xFFEED98A),
                    Color(0xFFB8D97B),
                    Color(0xFF4DC88D),
                  ]
                : const [
                    Color(0xFFB7F06B),
                    Color(0xFF55C76B),
                    Color(0xFF2FAE77),
                  ],
            fallbackAlpha: feature.kind == TerrainKind.shore ? 0.56 : 0.62,
            textureScale: feature.kind == TerrainKind.shore ? 0.3 : 0.24,
          ),
        );
        canvas.drawPath(
          path,
          Paint()
            ..color = const Color(0xFF154B32).withValues(alpha: 0.08)
            ..style = PaintingStyle.fill,
        );
        _drawVectorLandColorGrade(canvas, path, feature.kind);
      }

      _drawLandTexture(canvas, path);
    }
  }

  void _drawVectorLandColorGrade(
    Canvas canvas,
    Path path,
    TerrainKind kind,
  ) {
    final bounds = path.getBounds();
    if (bounds.isEmpty) return;
    final colors = kind == TerrainKind.shore
        ? const [Color(0x44F7E9A0), Color(0x334FCB7B)]
        : const [
            Color(0x553FD36B),
            Color(0x4430B667),
            Color(0x551B8F59),
          ];
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ).createShader(bounds)
        ..style = PaintingStyle.fill,
    );
  }

  void _drawSoftTerrainTiles(
    Canvas canvas,
    List<_ProjectedTerrainTile> tiles,
    double tileWidth,
    double tileHeight,
  ) {
    for (final tile in tiles) {
      final isShore = tile.data.kind == TerrainKind.shore;
      final radius = isShore ? tileWidth * 0.88 : tileWidth * 1.15;
      final rect = Rect.fromCenter(
        center: tile.center,
        width: radius * 1.65,
        height: tileHeight * (isShore ? 1.45 : 1.9),
      );
      canvas.drawOval(
        rect,
        _texturedFillPaint(
          isShore ? TerrainKind.shore : TerrainKind.land,
          rect,
          fallbackColors: [
            isShore ? const Color(0xFFEED98A) : const Color(0xFF45C772),
            isShore ? const Color(0xFF86DB8E) : const Color(0xFF2FAE77),
          ],
          fallbackAlpha: isShore ? 0.2 : 0.22,
          textureScale: isShore ? 0.28 : 0.23,
        )..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
    }
  }

  void _drawFallbackRoads(
    Canvas canvas,
    List<_ProjectedTerrainTile> roadTiles,
    double tileWidth,
  ) {
    if (roadTiles.isEmpty) return;
    final roadPath = Path();
    for (var i = 0; i < roadTiles.length; i++) {
      final current = roadTiles[i];
      _ProjectedTerrainTile? nearest;
      var nearestDistance = double.infinity;
      for (var j = i + 1; j < roadTiles.length; j++) {
        final candidate = roadTiles[j];
        final distance = (candidate.center - current.center).distance;
        if (distance < nearestDistance && distance <= tileWidth * 1.55) {
          nearest = candidate;
          nearestDistance = distance;
        }
      }
      if (nearest == null) continue;
      roadPath
        ..moveTo(current.center.dx, current.center.dy)
        ..lineTo(nearest.center.dx, nearest.center.dy);
    }
    if (roadPath.getBounds().isEmpty) return;
    canvas.drawPath(
      roadPath,
      Paint()
        ..color = const Color(0xFF12313A).withValues(alpha: 0.82)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      roadPath,
      _texturedStrokePaint(
        TerrainKind.road,
        roadPath.getBounds(),
        fallbackColor: const Color(0xFFE5ECE6).withValues(alpha: 0.92),
        width: 5.2,
      ),
    );
    canvas.drawPath(
      roadPath,
      Paint()
        ..color = const Color(0xFF88F4EF).withValues(alpha: 0.58)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _drawFallbackPiers(
    Canvas canvas,
    List<_ProjectedTerrainTile> pierTiles,
    double tileWidth,
    double tileHeight,
  ) {
    final paint = Paint()
      ..color = const Color(0xFFFFC982).withValues(alpha: 0.38)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    for (final tile in pierTiles) {
      canvas.drawLine(
        tile.center.translate(0, -tileHeight * 0.38),
        tile.center.translate(0, tileHeight * 0.38),
        paint,
      );
    }
  }

  void _drawCoastlineLayer(Canvas canvas, Size size) {
    for (final feature in terrainFeatures) {
      if (feature.kind != TerrainKind.water &&
          feature.kind != TerrainKind.land &&
          feature.kind != TerrainKind.shore) {
        continue;
      }
      final path = _pathForFeature(feature);
      if (path == null) continue;

      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFFEFFFD8).withValues(alpha: 0.56)
          ..style = PaintingStyle.stroke
          ..strokeWidth = feature.kind == TerrainKind.water ? 2.4 : 6.0
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF0A7284).withValues(alpha: 0.46)
          ..style = PaintingStyle.stroke
          ..strokeWidth = feature.kind == TerrainKind.water ? 1.2 : 2.0
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  // ignore: unused_element
  void _drawCoastlineGlowLayer(Canvas canvas, Size size) {
    for (final feature in terrainFeatures) {
      if (feature.kind != TerrainKind.water &&
          feature.kind != TerrainKind.land &&
          feature.kind != TerrainKind.shore) {
        continue;
      }
      final path = _pathForFeature(feature);
      if (path == null) continue;
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFFBAFFF3).withValues(alpha: 0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = feature.kind == TerrainKind.water ? 8 : 12
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }
  }

  void _drawCoastlineDepthLayer(Canvas canvas, Size size) {
    const coastlineKinds = {
      TerrainKind.water,
      TerrainKind.land,
      TerrainKind.shore,
    };
    final viewport = Offset.zero & size;
    for (final feature in terrainFeatures) {
      if (!coastlineKinds.contains(feature.kind)) continue;
      final path = _pathForFeature(feature);
      if (path == null || !path.getBounds().inflate(14).overlaps(viewport)) {
        continue;
      }
      final midpoint = feature.points[feature.points.length ~/ 2];
      final depthScale = camera.depthScaleFor(midpoint);
      final submergedWidth = (10 * depthScale).clamp(6.0, 13.0).toDouble();
      final shallowWidth = (5.5 * depthScale).clamp(3.2, 7.2).toDouble();
      final foamWidth = (1.4 * depthScale).clamp(0.8, 1.9).toDouble();

      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF07596A).withValues(alpha: 0.56)
          ..style = PaintingStyle.stroke
          ..strokeWidth = submergedWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF38D6CF).withValues(alpha: 0.34)
          ..style = PaintingStyle.stroke
          ..strokeWidth = shallowWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFFFFF8E8).withValues(alpha: 0.34)
          ..style = PaintingStyle.stroke
          ..strokeWidth = foamWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  void _drawBuildingLayer(Canvas canvas, Size size) {
    final budget = _renderBudget;
    final visibleBuildings = terrainFeatures
        .where(isRenderableBuildingFeature)
        .where(
          (feature) => feature.points.any(
            (point) => camera.isVisible(point, paddingMeters: 80),
          ),
        )
        .toList()
      ..sort((left, right) {
        final leftMidpoint = left.points[left.points.length ~/ 2];
        final rightMidpoint = right.points[right.points.length ~/ 2];
        return camera
            .project(leftMidpoint)
            .dy
            .compareTo(camera.project(rightMidpoint).dy);
      });
    final viewport = Offset.zero & size;

    for (final feature in visibleBuildings.take(budget.maxBuildings)) {
      final path = _pathForFeature(feature);
      if (path == null || !path.getBounds().inflate(18).overlaps(viewport)) {
        continue;
      }
      final midpoint = feature.points[feature.points.length ~/ 2];
      final style = GameBuildingStyle.forFeature(
        feature,
        depthScale: camera.depthScaleFor(midpoint),
        simplified: !budget.enableBuildingRoofDetail,
      );
      final extrusion = Offset(0, style.extrusionPixels);
      final shadowPaint = Paint()
        ..color = const Color(0xFF102F34).withValues(alpha: 0.24);
      if (style.drawRoofDetail) {
        shadowPaint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      }

      canvas.drawPath(
        path.shift(extrusion + const Offset(0, 2)),
        shadowPaint,
      );
      canvas.drawPath(path.shift(extrusion), Paint()..color = style.sideColor);
      canvas.drawPath(
        path.shift(extrusion),
        Paint()
          ..color = style.outlineColor.withValues(alpha: 0.72)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1,
      );
      canvas.drawPath(path, Paint()..color = style.roofColor);
      canvas.drawPath(
        path,
        Paint()
          ..color = style.outlineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..strokeJoin = StrokeJoin.round,
      );
      if (style.drawRoofDetail) {
        final bounds = path.getBounds();
        canvas.save();
        canvas.clipPath(path);
        canvas.drawLine(
          Offset(bounds.left + 3, bounds.top + 3),
          Offset(bounds.right - 3, bounds.top + 3),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.34)
            ..strokeWidth = 1.2
            ..strokeCap = StrokeCap.round,
        );
        canvas.restore();
      }
    }
  }

  void _drawRoadLayer(Canvas canvas, Size size) {
    final budget = _renderBudget;
    final roads = [
      for (final feature in terrainFeatures)
        if (feature.kind == TerrainKind.road) feature,
    ]..sort(
        (left, right) => GameRoadStyle.forFeature(left).drawPriority.compareTo(
              GameRoadStyle.forFeature(right).drawPriority,
            ),
      );

    for (final feature in roads) {
      final path = _pathForFeature(feature);
      if (path == null) continue;
      final style = _roadStyleForFeature(feature);

      if (budget.enableRoadMicroDetails) {
        _drawRoadShoulderBlend(canvas, path, style);
        _drawRoadBevelShadow(canvas, path, style);
      }
      if (style.drawsBridgeDeck) {
        _drawBridgeRoadDeck(
          canvas,
          path,
          style,
          enableMicroDetails: budget.enableRoadMicroDetails,
        );
      }
      _drawRoadCasing(
        canvas,
        path,
        width: style.casingWidth,
        includeGlow: budget.enableRoadMicroDetails,
      );
      canvas.drawPath(
        path,
        _texturedStrokePaint(
          TerrainKind.road,
          path.getBounds(),
          fallbackColor: const Color(0xFFE5ECE6).withValues(alpha: 0.96),
          width: style.surfaceWidth,
        ),
      );
      if (budget.enableRoadMicroDetails) {
        _drawRoadSurfaceGrain(canvas, path, style);
      }
      _drawRoadEdgeRim(canvas, path, style);
      if (style.hasPedestrianHighlight) {
        _drawPedestrianRoadHighlight(canvas, path, style);
      } else {
        _drawRoadCenterHighlight(canvas, path, style);
      }
      if (style.hasVehicleLaneMarkings) {
        _drawRoadLaneMarkings(canvas, path, style);
      }
    }
    if (budget.enableRoadMicroDetails) {
      _drawRoadIntersectionLayer(canvas, roads);
    }
  }

  GameRoadStyle _roadStyleForFeature(TerrainVectorFeature feature) {
    final midpoint = feature.points[feature.points.length ~/ 2];
    return GameRoadStyle.forFeature(feature).scaledBy(
      camera.depthScaleFor(midpoint),
    );
  }

  void _drawRoadShoulderBlend(
    Canvas canvas,
    Path path,
    GameRoadStyle style,
  ) {
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF83E7B0).withValues(alpha: 0.11)
        ..style = PaintingStyle.stroke
        ..strokeWidth = style.casingWidth + 12
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
    canvas.drawPath(
      path.shift(const Offset(0, 2.2)),
      Paint()
        ..color = const Color(0xFF052D34).withValues(alpha: 0.11)
        ..style = PaintingStyle.stroke
        ..strokeWidth = style.casingWidth + 9
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
  }

  void _drawRoadBevelShadow(
    Canvas canvas,
    Path path,
    GameRoadStyle style,
  ) {
    canvas.drawPath(
      path.shift(const Offset(1.8, 2.8)),
      Paint()
        ..color = const Color(0xFF01252D).withValues(alpha: 0.24)
        ..style = PaintingStyle.stroke
        ..strokeWidth = style.casingWidth + 5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5),
    );
    canvas.drawPath(
      path.shift(const Offset(-0.8, -1.0)),
      Paint()
        ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = style.casingWidth + 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
  }

  void _drawRoadCasing(
    Canvas canvas,
    Path path, {
    required double width,
    bool includeGlow = true,
  }) {
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF052B35).withValues(alpha: 0.74)
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    if (includeGlow) {
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFFBFF9EF).withValues(alpha: 0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = width + 4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    }
  }

  void _drawBridgeRoadDeck(
    Canvas canvas,
    Path path,
    GameRoadStyle style, {
    required bool enableMicroDetails,
  }) {
    if (enableMicroDetails) {
      canvas.drawPath(
        path.shift(const Offset(1.8, 3.4)),
        Paint()
          ..color = const Color(0xFF01252D).withValues(alpha: 0.32)
          ..style = PaintingStyle.stroke
          ..strokeWidth = style.casingWidth + 8
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5),
      );
    }
    _drawRoadCasing(
      canvas,
      path,
      width: style.casingWidth + 3,
      includeGlow: false,
    );
    if (!enableMicroDetails) return;
    final railPaint = Paint()
      ..color = const Color(0xFFF3FFF4).withValues(alpha: 0.74)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final railOffset = style.casingWidth * 0.5 - 0.5;
    canvas.drawPath(_bridgeRailPath(path, -railOffset), railPaint);
    canvas.drawPath(_bridgeRailPath(path, railOffset), railPaint);
  }

  Path _bridgeRailPath(Path roadPath, double railOffset) {
    final railPath = Path();
    for (final metric in roadPath.computeMetrics()) {
      var hasPoint = false;
      final sampleStep = math.min(6.0, math.max(2.0, metric.length / 28));
      void addSample(double distance) {
        final tangent = metric.getTangentForOffset(distance);
        if (tangent == null) return;
        final normal = Offset(-tangent.vector.dy, tangent.vector.dx);
        final normalLength = normal.distance;
        if (normalLength == 0) return;
        final point = tangent.position + normal / normalLength * railOffset;
        if (hasPoint) {
          railPath.lineTo(point.dx, point.dy);
        } else {
          railPath.moveTo(point.dx, point.dy);
          hasPoint = true;
        }
      }

      for (var distance = 0.0;
          distance < metric.length;
          distance += sampleStep) {
        addSample(distance);
      }
      addSample(metric.length);
    }
    return railPath;
  }

  void _drawRoadEdgeRim(Canvas canvas, Path path, GameRoadStyle style) {
    final rimPaint = Paint()
      ..color = const Color(0xFFEFFFF8).withValues(alpha: 0.24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final offset = style.surfaceWidth * 0.25;
    canvas.drawPath(path.shift(Offset(-offset, -offset * 0.6)), rimPaint);
    canvas.drawPath(
      path.shift(Offset(offset, offset * 0.6)),
      Paint()
        ..color = const Color(0xFF07313A).withValues(alpha: 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _drawRoadCenterHighlight(
    Canvas canvas,
    Path path,
    GameRoadStyle style,
  ) {
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.66)
        ..style = PaintingStyle.stroke
        ..strokeWidth = style.surfaceWidth >= 5 ? 1.2 : 0.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF40DAD2).withValues(alpha: 0.34)
        ..style = PaintingStyle.stroke
        ..strokeWidth = style.surfaceWidth >= 5 ? 2.2 : 1.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _drawRoadLaneMarkings(
    Canvas canvas,
    Path path,
    GameRoadStyle style,
  ) {
    final markPaint = Paint()
      ..color = const Color(0xFFFFF8DE).withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = style.surfaceWidth >= 7 ? 1.35 : 1.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final glowPaint = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = style.surfaceWidth >= 7 ? 3.2 : 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.4);

    for (final metric in path.computeMetrics()) {
      var distance = 12.0;
      while (distance < metric.length) {
        final end = math.min(distance + 9, metric.length);
        final dash = metric.extractPath(distance, end);
        canvas.drawPath(dash, glowPaint);
        canvas.drawPath(dash, markPaint);
        distance += 26;
      }
    }
  }

  void _drawPedestrianRoadHighlight(
    Canvas canvas,
    Path path,
    GameRoadStyle style,
  ) {
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFE8FFF3).withValues(alpha: 0.52)
        ..style = PaintingStyle.stroke
        ..strokeWidth = style.surfaceWidth * 0.35
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _drawRoadSurfaceGrain(
    Canvas canvas,
    Path path,
    GameRoadStyle style,
  ) {
    final grainPaint = Paint()
      ..color = const Color(0xFF0B5360).withValues(alpha: 0.13)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.85
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final glintPaint = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.65
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (final metric in path.computeMetrics()) {
      if (metric.length < 28) continue;
      var distance = 8.0;
      var index = 0;
      while (distance < metric.length) {
        final tangent = metric.getTangentForOffset(distance);
        if (tangent == null) break;
        final normal = Offset(-tangent.vector.dy, tangent.vector.dx);
        final side = index.isEven ? 1.0 : -1.0;
        final center =
            tangent.position + normal * side * style.surfaceWidth * 0.3;
        final segment = Path()
          ..moveTo(center.dx - tangent.vector.dx * 2.4,
              center.dy - tangent.vector.dy * 2.4)
          ..lineTo(center.dx + tangent.vector.dx * 2.4,
              center.dy + tangent.vector.dy * 2.4);
        canvas.drawPath(segment, index % 3 == 0 ? glintPaint : grainPaint);
        distance += 13 + (index % 4) * 3;
        index++;
      }
    }
  }

  void _drawRoadIntersectionLayer(
    Canvas canvas,
    List<TerrainVectorFeature> roads,
  ) {
    final groups = <List<_RoadEndpoint>>[];
    for (final road in roads) {
      if (road.points.length < 2) continue;
      final style = _roadStyleForFeature(road);
      for (final point in [road.points.first, road.points.last]) {
        final endpoint = _RoadEndpoint(
          position: camera.project(point),
          style: style,
        );
        List<_RoadEndpoint>? group;
        for (final candidate in groups) {
          if ((candidate.first.position - endpoint.position).distance <= 3) {
            group = candidate;
            break;
          }
        }
        final endpointGroup = group ?? <_RoadEndpoint>[];
        if (group == null) groups.add(endpointGroup);
        endpointGroup.add(endpoint);
      }
    }

    for (final group in groups) {
      if (group.length < 2) continue;
      var highestPriority = group.first.style;
      for (final endpoint in group.skip(1)) {
        if (endpoint.style.drawPriority > highestPriority.drawPriority) {
          highestPriority = endpoint.style;
        }
      }
      final center = Offset(
        group.map((endpoint) => endpoint.position.dx).reduce((a, b) => a + b) /
            group.length,
        group.map((endpoint) => endpoint.position.dy).reduce((a, b) => a + b) /
            group.length,
      );
      canvas.drawCircle(
        center.translate(1.1, 1.8),
        highestPriority.casingWidth * 0.58,
        Paint()
          ..color = const Color(0xFF012C35).withValues(alpha: 0.22)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
      canvas.drawCircle(
        center,
        highestPriority.casingWidth * 0.54,
        Paint()..color = const Color(0xFF07313A).withValues(alpha: 0.76),
      );
      canvas.drawCircle(
        center,
        highestPriority.surfaceWidth * 0.54,
        Paint()..color = const Color(0xFFE5ECE6).withValues(alpha: 0.96),
      );
    }
  }

  // ignore: unused_element
  void _drawPierLayer(Canvas canvas, Size size) {
    for (final feature in terrainFeatures) {
      if (feature.kind != TerrainKind.pier) continue;
      final path = _pathForFeature(feature);
      if (path == null) continue;

      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF3F2B24).withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.square
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFFC47A42).withValues(alpha: 0.78)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFFFFE6A9).withValues(alpha: 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  void _drawFishingSpotLayer(Canvas canvas, Size size) {
    for (final spot in fishingSpots) {
      final detail = _detailForFishingSpot(spot, size);
      if (detail == _FishingSpotMarkerDetail.full) {
        _drawFishingSpotInteractionAura(canvas, spot.screenPosition);
        _drawFishingSpotWaterReflection(canvas, spot.screenPosition);
        _drawFishingSpotMarker(canvas, spot.screenPosition);
      } else {
        _drawFishingSpotCompactMarker(canvas, spot.screenPosition);
      }
    }
  }

  _FishingSpotMarkerDetail _detailForFishingSpot(
    ProjectedFishingSpot spot,
    Size size,
  ) {
    final playerCenter = Offset(size.width * 0.5, size.height * 0.55);
    final screenDistance = (spot.screenPosition - playerCenter).distance;
    final fullDetailRadius =
        math.min(size.shortestSide * 0.48, camera.visibleRadiusMeters * 0.42);
    return screenDistance <= fullDetailRadius
        ? _FishingSpotMarkerDetail.full
        : _FishingSpotMarkerDetail.compact;
  }

  void _drawFishingSpotCompactMarker(Canvas canvas, Offset center) {
    _drawFishingSpotDepthShadow(canvas, center);
    final baseRect = Rect.fromCenter(
      center: center.translate(0, 2),
      width: 34,
      height: 15,
    );
    canvas.drawOval(
      baseRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFF58D), Color(0xFF19D7CA), Color(0xFF075D69)],
        ).createShader(baseRect),
    );
    canvas.drawCircle(
      center.translate(0, -12),
      12,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.28, -0.35),
          colors: [
            Colors.white.withValues(alpha: 0.92),
            const Color(0xFFFFF36D),
            const Color(0xFF0EA7AD),
          ],
          stops: const [0, 0.5, 1],
        ).createShader(
            Rect.fromCircle(center: center.translate(0, -12), radius: 13)),
    );
    canvas.drawCircle(
      center.translate(0, -12),
      12,
      Paint()
        ..color = const Color(0xFF07313A).withValues(alpha: 0.72)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );
    canvas.drawOval(
      Rect.fromCenter(center: center.translate(0, 5), width: 48, height: 18),
      Paint()
        ..color = const Color(0xFFDBFFFA).withValues(alpha: 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    _drawFishingSpotHookBadge(canvas, center.translate(0, 14));
  }

  void _drawFishingSpotInteractionAura(Canvas canvas, Offset center) {
    final auraCenter = center.translate(0, 10);
    final auraRect = Rect.fromCenter(center: auraCenter, width: 94, height: 46);
    canvas.drawOval(
      auraRect,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFE9FFF9).withValues(alpha: 0.22),
            const Color(0xFF18E0D1).withValues(alpha: 0.11),
            const Color(0xFF0A5F70).withValues(alpha: 0),
          ],
          stops: const [0, 0.58, 1],
        ).createShader(auraRect)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawOval(
      auraRect.deflate(5),
      Paint()
        ..color = const Color(0xFFECFFFB).withValues(alpha: 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    canvas.drawOval(
      Rect.fromCenter(center: auraCenter, width: 54, height: 22),
      Paint()
        ..color = const Color(0xFFFFF36D).withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  void _drawFishingSpotWaterReflection(Canvas canvas, Offset center) {
    final reflectionCenter = center.translate(0, 7);
    canvas.drawOval(
      Rect.fromCenter(
        center: reflectionCenter,
        width: 54,
        height: 17,
      ),
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFF36D).withValues(alpha: 0.35),
            const Color(0xFF12D6C6).withValues(alpha: 0.16),
            const Color(0xFF12D6C6).withValues(alpha: 0),
          ],
          stops: const [0, 0.48, 1],
        ).createShader(
          Rect.fromCenter(center: reflectionCenter, width: 58, height: 20),
        ),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: reflectionCenter.translate(0, 2),
        width: 34,
        height: 7,
      ),
      Paint()
        ..color = const Color(0xFF05343B).withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    _drawFishingSpotRippleRings(canvas, center);
  }

  void _drawFishingSpotRippleRings(Canvas canvas, Offset center) {
    for (var i = 0; i < 3; i++) {
      final alpha = 0.2 - i * 0.045;
      canvas.drawOval(
        Rect.fromCenter(
          center: center.translate(0, 11 + i * 1.6),
          width: 44 + i * 17,
          height: 14 + i * 6,
        ),
        Paint()
          ..color = const Color(0xFFDBFFFA).withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1,
      );
    }
  }

  void _drawLandmarkLabelLayer(Canvas canvas, Size size) {
    final labels = <_MapLabel>[];
    final seenLabelKeys = <String>{};
    final labelSafeRight = size.width - 96;
    for (final feature in terrainFeatures) {
      final label = _labelForFeature(feature);
      if (label == null) continue;
      final labelKey = '${feature.kind.name}:$label';
      if (!seenLabelKeys.add(labelKey)) continue;
      final anchor = _featureAnchor(feature);
      if (anchor == null) continue;
      if (anchor.dx < 18 ||
          anchor.dx > labelSafeRight ||
          anchor.dy < 92 ||
          anchor.dy > size.height - 118) {
        continue;
      }
      labels.add(_MapLabel(label, _iconForFeature(feature), anchor));
    }
    final usedFallbackKinds = <TerrainKind>{};
    for (final tile in terrainTiles) {
      final label = _fallbackLabelForTile(tile);
      if (label == null || usedFallbackKinds.contains(tile.kind)) {
        continue;
      }
      if (!camera.isVisible(tile.centerLatLng, paddingMeters: 80)) {
        continue;
      }
      final anchor = camera.project(tile.centerLatLng);
      if (anchor.dx < 18 ||
          anchor.dx > labelSafeRight ||
          anchor.dy < 92 ||
          anchor.dy > size.height - 118) {
        continue;
      }
      usedFallbackKinds.add(tile.kind);
      labels.add(_MapLabel(label, _iconForTile(tile), anchor));
    }

    labels.sort((a, b) => _labelPriority(a.icon).compareTo(
          _labelPriority(b.icon),
        ));

    final occupied = <Rect>[];
    for (final label in labels.take(_renderBudget.maxLabels)) {
      final rect = _labelRect(label, size);
      if (occupied.any((other) => other.overlaps(rect.inflate(8)))) {
        continue;
      }
      occupied.add(rect);
      _drawLabelPill(canvas, label, rect);
    }
  }

  void _drawAtmosphereLayer(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFFFFFFF).withValues(alpha: 0.06),
            Colors.transparent,
            const Color(0xFF022C39).withValues(alpha: 0.28),
          ],
          stops: const [0, 0.48, 1],
        ).createShader(rect),
    );

    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.53),
      size.shortestSide * 0.46,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1,
    );
  }

  Path? _pathForFeature(TerrainVectorFeature feature) {
    if (feature.points.length < 2) return null;
    final path = Path();
    for (var i = 0; i < feature.points.length; i++) {
      final offset = camera.project(feature.points[i]);
      if (i == 0) {
        path.moveTo(offset.dx, offset.dy);
      } else {
        path.lineTo(offset.dx, offset.dy);
      }
    }
    if (feature.isClosed) path.close();
    return path;
  }

  Offset? _featureAnchor(TerrainVectorFeature feature) {
    if (feature.points.isEmpty) return null;
    if (feature.points.length == 1) {
      return camera.project(feature.points.single);
    }
    if (feature.kind == TerrainKind.road || feature.kind == TerrainKind.pier) {
      return camera.project(feature.points[feature.points.length ~/ 2]);
    }

    var dx = 0.0;
    var dy = 0.0;
    for (final point in feature.points) {
      final projected = camera.project(point);
      dx += projected.dx;
      dy += projected.dy;
    }
    return Offset(dx / feature.points.length, dy / feature.points.length);
  }

  String? _labelForFeature(TerrainVectorFeature feature) {
    if (feature.name.isEmpty) return null;
    return switch (feature.kind) {
      TerrainKind.road => _shortLabel(feature.name),
      TerrainKind.pier => _shortLabel(feature.name),
      TerrainKind.water => _shortLabel(feature.name),
      TerrainKind.shore => _shortLabel(feature.name),
      TerrainKind.land => null,
      TerrainKind.fishingNode => null,
      TerrainKind.building => null,
    };
  }

  String? _fallbackLabelForTile(TerrainTile tile) {
    return switch (tile.kind) {
      TerrainKind.road => '道路',
      TerrainKind.pier => '碼頭',
      TerrainKind.shore => '岸線',
      TerrainKind.water => null,
      TerrainKind.land => null,
      TerrainKind.fishingNode => null,
      TerrainKind.building => null,
    };
  }

  String _shortLabel(String value) {
    const maxRunes = 8;
    final runes = value.runes.toList(growable: false);
    if (runes.length <= maxRunes) return value;
    return String.fromCharCodes(runes.take(maxRunes));
  }

  String _iconForFeature(TerrainVectorFeature feature) {
    return switch (feature.kind) {
      TerrainKind.road => '=',
      TerrainKind.pier => '|',
      TerrainKind.water => '~',
      TerrainKind.shore => '.',
      TerrainKind.land => '+',
      TerrainKind.fishingNode => 'o',
      TerrainKind.building => '',
    };
  }

  String _iconForTile(TerrainTile tile) {
    return switch (tile.kind) {
      TerrainKind.road => '=',
      TerrainKind.pier => '|',
      TerrainKind.shore => '.',
      TerrainKind.water => '~',
      TerrainKind.land => '+',
      TerrainKind.fishingNode => 'o',
      TerrainKind.building => '',
    };
  }

  int _labelPriority(String icon) {
    return switch (icon) {
      '=' => 0,
      '|' => 1,
      '~' => 2,
      _ => 3,
    };
  }

  Rect _labelRect(_MapLabel label, Size size) {
    final width = 58.0 + label.text.runes.length * 9.0;
    final clampedWidth = width.clamp(74.0, 142.0).toDouble();
    final minCenterX = 12 + clampedWidth * 0.5;
    final maxCenterX = math.max(
      minCenterX,
      size.width - 96 - clampedWidth * 0.5,
    );
    final center = Offset(
      label.anchor.dx
          .clamp(
            minCenterX,
            maxCenterX,
          )
          .toDouble(),
      (label.anchor.dy - 18).clamp(108.0, size.height - 132).toDouble(),
    );
    return Rect.fromCenter(
      center: center,
      width: clampedWidth,
      height: 30,
    );
  }

  void _drawLabelPill(Canvas canvas, _MapLabel label, Rect rect) {
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(15));
    canvas.drawRRect(
      rrect.shift(const Offset(0, 3)),
      Paint()..color = const Color(0xFF052D37).withValues(alpha: 0.22),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xE6073640), Color(0xD90A5661)],
        ).createShader(rect),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = const Color(0xFFE9FFF6).withValues(alpha: 0.32)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    final iconCenter = Offset(rect.left + 17, rect.center.dy);
    canvas.drawCircle(
      iconCenter,
      10,
      Paint()..color = const Color(0xFFFFD95E).withValues(alpha: 0.92),
    );
    _paintText(
      canvas,
      label.icon,
      iconCenter,
      fontSize: 12,
      color: const Color(0xFF06323B),
      weight: FontWeight.w800,
      centered: true,
    );
    _paintText(
      canvas,
      label.text,
      Offset(rect.left + 33, rect.center.dy - 7),
      fontSize: 12,
      color: Colors.white,
      weight: FontWeight.w700,
    );
  }

  void _paintText(
    Canvas canvas,
    String text,
    Offset offset, {
    required double fontSize,
    required Color color,
    required FontWeight weight,
    bool centered = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: weight,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: 102);
    painter.paint(
      canvas,
      centered
          ? offset - Offset(painter.width * 0.5, painter.height * 0.5)
          : offset,
    );
  }

  void _drawLandTexture(Canvas canvas, Path path) {
    final bounds = path.getBounds();
    if (bounds.isEmpty) return;
    final grassPaint = Paint()
      ..color = const Color(0xFFE2FF8B).withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    for (var x = bounds.left; x < bounds.right; x += 22) {
      final start = Offset(x, bounds.top + 10);
      final end = Offset(x + 14, bounds.bottom - 8);
      canvas.drawLine(start, end, grassPaint);
    }
  }

  Paint _texturedFillPaint(
    TerrainKind kind,
    Rect rect, {
    required List<Color> fallbackColors,
    double fallbackAlpha = 1,
    double textureScale = 0.28,
  }) {
    final image = texturePack.imageFor(kind);
    if (image == null) {
      return Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            for (final color in fallbackColors)
              color.withValues(alpha: fallbackAlpha),
          ],
        ).createShader(rect)
        ..style = PaintingStyle.fill;
    }
    return Paint()
      ..shader = ui.ImageShader(
        image,
        ui.TileMode.repeated,
        ui.TileMode.repeated,
        Matrix4.diagonal3Values(textureScale, textureScale, 1).storage,
      )
      ..style = PaintingStyle.fill;
  }

  Paint _texturedStrokePaint(
    TerrainKind kind,
    Rect rect, {
    required Color fallbackColor,
    required double width,
  }) {
    final image = texturePack.imageFor(kind);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (image == null) {
      return paint..color = fallbackColor;
    }
    return paint
      ..shader = ui.ImageShader(
        image,
        ui.TileMode.repeated,
        ui.TileMode.repeated,
        Matrix4.diagonal3Values(0.42, 0.42, 1).storage,
      );
  }

  void _drawFishingSpotMarker(Canvas canvas, Offset center) {
    _drawFishingSpotBeaconGlow(canvas, center);
    _drawFishingSpotDepthShadow(canvas, center);
    _drawFishingSpotProximityRing(canvas, center);
    _drawFishingSpotFloatingPlatform(canvas, center);
    _drawFishingSpot3DBase(canvas, center);
    _drawFishingSpotBuoyColumn(canvas, center);
    canvas.drawPath(
      Path()
        ..moveTo(center.dx, center.dy - 36)
        ..quadraticBezierTo(
            center.dx + 18, center.dy - 28, center.dx + 9, center.dy - 10)
        ..quadraticBezierTo(center.dx + 4, center.dy - 2, center.dx, center.dy)
        ..quadraticBezierTo(
            center.dx - 4, center.dy - 2, center.dx - 9, center.dy - 10)
        ..quadraticBezierTo(
            center.dx - 18, center.dy - 28, center.dx, center.dy - 36)
        ..close(),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFF570), Color(0xFF12D6C6)],
        ).createShader(Rect.fromCircle(center: center, radius: 36)),
    );
    canvas.drawCircle(
      center.translate(0, -21),
      8,
      Paint()
        ..color = const Color(0xFF062E38).withValues(alpha: 0.62)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawCircle(
      center.translate(0, -21),
      27,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFF36D).withValues(alpha: 0.35),
            const Color(0xFFFFF36D).withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: 27)),
    );
    canvas.drawCircle(
      center.translate(0, 2),
      16,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFF36D).withValues(alpha: 0.28),
            const Color(0xFFFFF36D).withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: 16)),
    );
    _drawFishingSpotRarityCrown(canvas, center);
    _drawFishingSpotHookBadge(canvas, center);
  }

  void _drawFishingSpotBeaconGlow(Canvas canvas, Offset center) {
    final beamRect = Rect.fromLTWH(center.dx - 16, center.dy - 82, 32, 74);
    canvas.drawRRect(
      RRect.fromRectAndRadius(beamRect, const Radius.circular(16)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFFFF36D).withValues(alpha: 0),
            const Color(0xFFFFF36D).withValues(alpha: 0.3),
            const Color(0xFF12D6C6).withValues(alpha: 0.08),
            const Color(0xFF12D6C6).withValues(alpha: 0),
          ],
          stops: const [0, 0.42, 0.76, 1],
        ).createShader(beamRect)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    final glowCenter = center.translate(0, -38);
    canvas.drawCircle(
      glowCenter,
      25,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.3),
            const Color(0xFFFFF36D).withValues(alpha: 0.22),
            const Color(0xFF12D6C6).withValues(alpha: 0),
          ],
          stops: const [0, 0.5, 1],
        ).createShader(Rect.fromCircle(center: glowCenter, radius: 25)),
    );
  }

  void _drawFishingSpot3DBase(Canvas canvas, Offset center) {
    final shadowRect = Rect.fromCenter(
      center: center.translate(0, 8),
      width: 48,
      height: 15,
    );
    canvas.drawOval(
      shadowRect,
      Paint()
        ..color = const Color(0xFF01323A).withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawOval(
      Rect.fromCenter(center: center.translate(0, 3), width: 40, height: 18),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFF8A5), Color(0xFF20D9CF), Color(0xFF087985)],
        ).createShader(Rect.fromCenter(
          center: center.translate(0, 3),
          width: 40,
          height: 18,
        )),
    );
    canvas.drawOval(
      Rect.fromCenter(center: center.translate(0, 1), width: 29, height: 12),
      Paint()
        ..color = const Color(0xFFFFF6A6).withValues(alpha: 0.72)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  void _drawFishingSpotDepthShadow(Canvas canvas, Offset center) {
    final shadowCenter = center.translate(0, 15);
    canvas.drawOval(
      Rect.fromCenter(center: shadowCenter, width: 64, height: 18),
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF01252C).withValues(alpha: 0.34),
            const Color(0xFF01252C).withValues(alpha: 0.12),
            Colors.transparent,
          ],
          stops: const [0, 0.54, 1],
        ).createShader(
          Rect.fromCenter(center: shadowCenter, width: 64, height: 18),
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
  }

  void _drawFishingSpotProximityRing(Canvas canvas, Offset center) {
    final ringCenter = center.translate(0, 8);
    final outer = Rect.fromCenter(center: ringCenter, width: 76, height: 28);
    canvas.drawArc(
      outer,
      math.pi * 0.08,
      math.pi * 1.34,
      false,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFFFF178), Color(0xFF18E2D5), Color(0xFF0B7987)],
        ).createShader(outer)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawArc(
      outer.deflate(7),
      math.pi * 1.18,
      math.pi * 0.52,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.34)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawFishingSpotFloatingPlatform(Canvas canvas, Offset center) {
    final platformCenter = center.translate(0, 4);
    final platformRect =
        Rect.fromCenter(center: platformCenter, width: 48, height: 21);
    canvas.drawOval(
      platformRect.shift(const Offset(2, 4)),
      Paint()
        ..color = const Color(0xFF012E36).withValues(alpha: 0.26)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.8),
    );
    canvas.drawOval(
      platformRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFF7A6), Color(0xFF22D6C8), Color(0xFF066A78)],
          stops: [0, 0.5, 1],
        ).createShader(platformRect),
    );
    canvas.drawOval(
      platformRect.deflate(5),
      Paint()
        ..color = const Color(0xFFFFF7C7).withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    for (final xOffset in const [-14.0, 14.0]) {
      final floatRect = Rect.fromCenter(
        center: platformCenter.translate(xOffset, 1),
        width: 9,
        height: 14,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(floatRect, const Radius.circular(5)),
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFFFF), Color(0xFFFFE85D), Color(0xFF0D8C96)],
          ).createShader(floatRect),
      );
    }
  }

  void _drawFishingSpotBuoyColumn(Canvas canvas, Offset center) {
    final poleRect = Rect.fromLTWH(center.dx - 4, center.dy - 40, 8, 39);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        poleRect.shift(const Offset(2, 2)),
        const Radius.circular(5),
      ),
      Paint()
        ..color = const Color(0xFF02313A).withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(poleRect, const Radius.circular(5)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF0BAEA9), Color(0xFFFFF275), Color(0xFFFFFDF0)],
          stops: [0, 0.56, 1],
        ).createShader(poleRect),
    );
    final capCenter = center.translate(0, -39);
    canvas.drawCircle(
      capCenter,
      12,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.42),
          colors: [
            Colors.white.withValues(alpha: 0.92),
            const Color(0xFFFFF36E),
            const Color(0xFF0E9DA7),
          ],
          stops: const [0, 0.48, 1],
        ).createShader(Rect.fromCircle(center: capCenter, radius: 13)),
    );
    canvas.drawCircle(
      capCenter,
      12,
      Paint()
        ..color = const Color(0xFF07313A).withValues(alpha: 0.78)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4,
    );
  }

  void _drawFishingSpotRarityCrown(Canvas canvas, Offset center) {
    final crownCenter = center.translate(-15, -42);
    final crownPath = Path()
      ..moveTo(crownCenter.dx - 9, crownCenter.dy + 5)
      ..lineTo(crownCenter.dx - 7, crownCenter.dy - 4)
      ..lineTo(crownCenter.dx - 2, crownCenter.dy + 1)
      ..lineTo(crownCenter.dx + 2, crownCenter.dy - 7)
      ..lineTo(crownCenter.dx + 7, crownCenter.dy + 1)
      ..lineTo(crownCenter.dx + 10, crownCenter.dy - 4)
      ..lineTo(crownCenter.dx + 9, crownCenter.dy + 5)
      ..close();
    canvas.drawPath(
      crownPath.shift(const Offset(1.2, 1.8)),
      Paint()
        ..color = const Color(0xFF032F37).withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2),
    );
    canvas.drawPath(
      crownPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFFFF), Color(0xFFFFF36D), Color(0xFFFF9F1C)],
        ).createShader(Rect.fromCircle(center: crownCenter, radius: 12)),
    );
    canvas.drawPath(
      crownPath,
      Paint()
        ..color = const Color(0xFF07313A).withValues(alpha: 0.52)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _drawFishingSpotHookBadge(Canvas canvas, Offset center) {
    final badgeCenter = center.translate(17, -39);
    canvas.drawCircle(
      badgeCenter,
      10,
      Paint()
        ..color = const Color(0xFF052E38).withValues(alpha: 0.96)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.6),
    );
    canvas.drawCircle(
      badgeCenter,
      9,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0CE9E0), Color(0xFF075D6A)],
        ).createShader(Rect.fromCircle(center: badgeCenter, radius: 9)),
    );
    final hookPath = Path()
      ..moveTo(badgeCenter.dx + 1.2, badgeCenter.dy - 5)
      ..lineTo(badgeCenter.dx + 1.2, badgeCenter.dy + 1.8)
      ..cubicTo(
        badgeCenter.dx + 1.2,
        badgeCenter.dy + 6.5,
        badgeCenter.dx - 5,
        badgeCenter.dy + 5.8,
        badgeCenter.dx - 4.5,
        badgeCenter.dy + 1.8,
      );
    canvas.drawPath(
      hookPath,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.92)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      badgeCenter.translate(1.2, -5),
      1.6,
      Paint()..color = Colors.white.withValues(alpha: 0.92),
    );
  }

  @override
  bool shouldRepaint(covariant GameMapPainter oldDelegate) =>
      !_sameCamera(oldDelegate.camera, camera) ||
      !_sameTerrainTiles(oldDelegate.terrainTiles, terrainTiles) ||
      !_sameTerrainFeatures(oldDelegate.terrainFeatures, terrainFeatures) ||
      !_sameFishingSpots(oldDelegate.fishingSpots, fishingSpots) ||
      oldDelegate.texturePack != texturePack;

  bool _sameCamera(GameMapCamera a, GameMapCamera b) =>
      a.center.latitude == b.center.latitude &&
      a.center.longitude == b.center.longitude &&
      a.visibleRadiusMeters == b.visibleRadiusMeters &&
      a.bearingDegrees == b.bearingDegrees &&
      a.viewportSize == b.viewportSize;

  bool _sameTerrainFeatures(
    List<TerrainVectorFeature> a,
    List<TerrainVectorFeature> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final left = a[i];
      final right = b[i];
      if (left.kind != right.kind ||
          left.name != right.name ||
          left.isClosed != right.isClosed ||
          left.roadClass != right.roadClass ||
          left.isBridge != right.isBridge ||
          left.lanes != right.lanes ||
          !_sameLatLngList(left.points, right.points)) {
        return false;
      }
    }
    return true;
  }

  bool _sameTerrainTiles(List<TerrainTile> a, List<TerrainTile> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  bool _sameFishingSpots(
    List<ProjectedFishingSpot> a,
    List<ProjectedFishingSpot> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final left = a[i];
      final right = b[i];
      if (left.id != right.id ||
          left.name != right.name ||
          left.position.latitude != right.position.latitude ||
          left.position.longitude != right.position.longitude ||
          left.screenPosition != right.screenPosition) {
        return false;
      }
    }
    return true;
  }

  bool _sameLatLngList(List<LatLng> a, List<LatLng> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].latitude != b[i].latitude || a[i].longitude != b[i].longitude) {
        return false;
      }
    }
    return true;
  }
}

class _MapLabel {
  const _MapLabel(this.text, this.icon, this.anchor);

  final String text;
  final String icon;
  final Offset anchor;
}
