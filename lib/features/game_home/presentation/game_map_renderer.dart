import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../domain/game_map_camera.dart';
import '../domain/game_map_feature_store.dart';
import '../domain/terrain_data_source.dart';

class _ProjectedTerrainTile {
  const _ProjectedTerrainTile(this.data, this.center);

  final TerrainTile data;
  final Offset center;
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
      TerrainKind.land => grassMicro ?? land,
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

  @override
  void paint(Canvas canvas, Size size) {
    _drawHorizonLayer(canvas, size);
    _drawPerspectiveMicroTileLayer(canvas, size);
    _drawTerrainDetailLayer(canvas, size);
    _drawImagegenInspiredMapLayer(canvas, size);
    _drawRoadLayer(canvas, size);
    _drawPierLayer(canvas, size);
    _drawLandmarkLabelLayer(canvas, size);
    _drawFishingSpotLayer(canvas, size);
    _drawAtmosphereLayer(canvas, size);
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
        ..strokeWidth = tile.kind == TerrainKind.land ? 0 : 0.28,
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
          TerrainKind.land => const [
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
      }
      canvas.restore();
    }
  }

  void _drawImagegenInspiredMapLayer(Canvas canvas, Size size) {
    if (terrainTiles.isEmpty) return;
    final visibleTiles = terrainTiles
        .where((tile) => camera.isVisible(tile.centerLatLng, paddingMeters: 80))
        .toList(growable: false);
    _drawTreeCanopyClusters(canvas, size, visibleTiles);
    _drawShoreRockDetails(canvas, size, visibleTiles);
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
      if ((tile.row * 5 + tile.col * 3) % 7 > 2) continue;
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

    for (var i = 0; i < 7; i++) {
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
        _drawWaterTileRipples(
          canvas,
          rect.center,
          rect.width,
          rect.height,
          variant,
        );
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
    }
  }

  void _drawSeedreamLandMicroTile(Canvas canvas, Rect rect, int variant) {
    final baseImage =
        texturePack.grassMicro ?? texturePack.grassMid ?? texturePack.land;
    if (baseImage == null) return;
    const tileScale = 0.032;
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
          const Color(0xFFE8FFC0).withValues(alpha: 0.9),
          BlendMode.modulate,
        )
        ..style = PaintingStyle.fill,
    );
    final toneImage = _landMicroImageForVariant(variant);
    if (toneImage == null || identical(toneImage, baseImage)) return;
    final toneAlpha = switch (variant.abs() % 6) {
      0 => 0.10,
      1 => 0.14,
      2 => 0.08,
      3 => 0.16,
      4 => 0.12,
      _ => 0.06,
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
    const tileScale = 0.04;
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
      TerrainKind.land => Colors.transparent,
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

  // ignore: unused_element
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
      }

      _drawLandTexture(canvas, path);
    }
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

  // ignore: unused_element
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

  // ignore: unused_element
  void _drawRoadLayer(Canvas canvas, Size size) {
    for (final feature in terrainFeatures) {
      if (feature.kind != TerrainKind.road) continue;
      final path = _pathForFeature(feature);
      if (path == null) continue;

      _drawRoadCasing(canvas, path, width: 12.5);
      canvas.drawPath(
        path,
        _texturedStrokePaint(
          TerrainKind.road,
          path.getBounds(),
          fallbackColor: const Color(0xFFE5ECE6).withValues(alpha: 0.96),
          width: 6.6,
        ),
      );
      _drawRoadCenterHighlight(canvas, path);
    }
  }

  void _drawRoadCasing(Canvas canvas, Path path, {required double width}) {
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF052B35).withValues(alpha: 0.74)
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
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

  void _drawRoadCenterHighlight(Canvas canvas, Path path) {
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.66)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF40DAD2).withValues(alpha: 0.34)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
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
      _drawFishingSpotWaterReflection(canvas, spot.screenPosition);
      _drawFishingSpotMarker(canvas, spot.screenPosition);
    }
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
  }

  void _drawLandmarkLabelLayer(Canvas canvas, Size size) {
    final labels = <_MapLabel>[];
    for (final feature in terrainFeatures) {
      final label = _labelForFeature(feature);
      if (label == null) continue;
      final anchor = _featureAnchor(feature);
      if (anchor == null) continue;
      if (anchor.dx < 18 ||
          anchor.dx > size.width - 18 ||
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
          anchor.dx > size.width - 18 ||
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
    for (final label in labels.take(7)) {
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
    final center = Offset(
      label.anchor.dx
          .clamp(
            12 + clampedWidth * 0.5,
            size.width - 12 - clampedWidth * 0.5,
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
