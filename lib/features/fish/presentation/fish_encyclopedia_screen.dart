import 'package:flutter/material.dart';

import '../data/fish_real_photo_urls.dart';
import '../data/fish_species_repository.dart';
import '../data/sample_fish_species_repository.dart';
import '../domain/fish_catalog_view_model.dart';
import '../domain/fish_collection_service.dart';
import '../domain/fish_collection_copy.dart';
import '../domain/fish_collection_status.dart';
import '../domain/fish_species.dart';
import 'fish_encyclopedia_semantics.dart';

class FishEncyclopediaScreen extends StatefulWidget {
  const FishEncyclopediaScreen({
    super.key,
    this.repository,
    this.onOpenMap,
  });

  final FishSpeciesRepository? repository;
  final VoidCallback? onOpenMap;

  @override
  State<FishEncyclopediaScreen> createState() => _FishEncyclopediaScreenState();
}

class _FishEncyclopediaScreenState extends State<FishEncyclopediaScreen> {
  late Future<List<FishSpecies>> _speciesFuture;
  Map<String, PlayerFishCollectionEntry> _collection = const {};
  var _isRefreshing = false;
  bool _hasLoadedOnce = false;
  FishCatalogFilter _filter = FishCatalogFilter.all;

  @override
  void initState() {
    super.initState();
    _speciesFuture = _loadSpecies();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Auto-refresh collection when user returns to this screen
    if (_hasLoadedOnce && !_isRefreshing) {
      _reloadCollection();
    }
  }

  Future<void> _reloadCollection() async {
    final collection = await FishCollectionService.loadAllSafe();
    if (mounted) {
      setState(() => _collection = collection);
    }
  }

  Future<List<FishSpecies>> _loadSpecies({bool forceRefresh = false}) async {
    setStateIfMounted(() {
      _isRefreshing = forceRefresh;
    });

    final repository = widget.repository ?? const SampleFishSpeciesRepository();
    final species = await repository
        .getSpecies(forceRefresh: forceRefresh)
        .timeout(
          const Duration(seconds: 8),
          onTimeout: () => const SampleFishSpeciesRepository().getSpecies(),
        )
        .catchError((_) => const SampleFishSpeciesRepository().getSpecies());
    final collection = await FishCollectionService.loadAllSafe();

    setStateIfMounted(() {
      _collection = collection;
      _isRefreshing = false;
      _hasLoadedOnce = true;
    });

    return species;
  }

  void _refresh() {
    setState(() {
      _speciesFuture = _loadSpecies(forceRefresh: true);
    });
  }

  void setStateIfMounted(VoidCallback callback) {
    if (mounted) setState(callback);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('香港魚類圖鑑'),
        actions: [
          IconButton(
            tooltip: '重新整理圖鑑',
            onPressed: _isRefreshing ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<FishSpecies>>(
        future: _speciesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return Semantics(
              container: true,
              liveRegion: true,
              label: '正在載入香港魚類圖鑑',
              child: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasError) {
            return _ErrorState(onRetry: _refresh);
          }

          final species = snapshot.data ?? const <FishSpecies>[];
          final visibleSpecies = FishCatalogViewModel.sortByNumber(
            FishCatalogViewModel.filter(species, _collection, _filter),
          );
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _CatalogProgressHeader(
                  total: species.length,
                  unlocked: _collection.values
                      .where(FishCatalogViewModel.isUnlocked)
                      .length,
                  verified: _collection.values
                      .where((entry) =>
                          entry.status == FishDiscoveryStatus.verifiedRealCatch)
                      .length,
                  filter: _filter,
                  onFilterChanged: (value) => setState(() => _filter = value),
                ),
              ),
              if (visibleSpecies.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Semantics(
                    container: true,
                    liveRegion: true,
                    label: fishEncyclopediaEmptyStateSemanticsLabel(_filter),
                    child: const Center(child: Text('這個分類暫時沒有魚種')),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                sliver: SliverLayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount =
                        _gridColumns(constraints.crossAxisExtent);
                    return SliverGrid.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 0.78,
                      ),
                      itemCount: visibleSpecies.length,
                      itemBuilder: (context, index) {
                        final item = visibleSpecies[index];
                        final status = _statusFor(item.id);
                        return _FishSpeciesCard(
                          species: item,
                          status: status,
                          entry: _collection[item.id],
                          onChanged: _refresh,
                          onOpenMap: widget.onOpenMap,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  int _gridColumns(double width) {
    if (width < 420) return 2;
    if (width < 900) return 3;
    return 4;
  }

  FishDiscoveryStatus _statusFor(String fishId) =>
      _collection[fishId]?.status ?? FishDiscoveryStatus.unknown;
}

class _CatalogProgressHeader extends StatelessWidget {
  const _CatalogProgressHeader({
    required this.total,
    required this.unlocked,
    required this.verified,
    required this.filter,
    required this.onFilterChanged,
  });

  final int total;
  final int unlocked;
  final int verified;
  final FishCatalogFilter filter;
  final ValueChanged<FishCatalogFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : unlocked / total;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$unlocked/$total 已解鎖',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              Text(
                '$verified 個魚鈎認證',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Semantics(
            container: true,
            excludeSemantics: true,
            label: fishEncyclopediaProgressSemanticsLabel(
              unlocked: unlocked,
              total: total,
              verified: verified,
            ),
            value: '$unlocked/$total',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 8,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final option in FishCatalogFilter.values) ...[
                  SizedBox(
                    width: _chipWidth(option),
                    child: ChoiceChip(
                      label: Center(
                        child: Text(
                          _label(option),
                          maxLines: 1,
                          softWrap: false,
                        ),
                      ),
                      showCheckmark: false,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                      selected: filter == option,
                      onSelected: (_) => onFilterChanged(option),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _label(FishCatalogFilter value) {
    return switch (value) {
      FishCatalogFilter.all => '全部',
      FishCatalogFilter.unlocked => '已釣獲',
      FishCatalogFilter.verified => '真實認證',
    };
  }

  double _chipWidth(FishCatalogFilter value) {
    return switch (value) {
      FishCatalogFilter.all => 92,
      FishCatalogFilter.unlocked => 112,
      FishCatalogFilter.verified => 132,
    };
  }
}

/// Keeps card semantics aligned with the discovery rules shown in the UI.
/// Unknown and encountered fish must not expose the species name before the
/// player completes the game catch.
String fishEncyclopediaCardSemanticsLabel({
  required String numberLabel,
  required String displayName,
  required FishDiscoveryStatus status,
  bool hasPhotoProof = false,
}) {
  final visibleName = status.showsBasicInfo ? displayName : '名稱未知';
  final photoProof = hasPhotoProof ? '，已附真實魚獲相片' : '';
  return '魚種 $numberLabel，$visibleName，'
      '${FishDiscoveryCopy.statusLabel(status)}$photoProof';
}

class _FishSpeciesCard extends StatelessWidget {
  const _FishSpeciesCard({
    required this.species,
    required this.status,
    required this.entry,
    required this.onChanged,
    required this.onOpenMap,
  });

  final FishSpecies species;
  final FishDiscoveryStatus status;
  final PlayerFishCollectionEntry? entry;
  final VoidCallback onChanged;
  final VoidCallback? onOpenMap;

  bool get _basicUnlocked => status.showsBasicInfo;
  bool get _fullUnlocked => status.showsFullInfo;
  bool get _colorIconUnlocked => status.showsColorIcon;
  bool get _photoProofUnlocked => entry?.showsPhotoProofBadge ?? false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final numberLabel = _speciesNumberLabel(species.id);

    final semanticsLabel = fishEncyclopediaCardSemanticsLabel(
      numberLabel: numberLabel,
      displayName: species.displayLocalName,
      status: status,
      hasPhotoProof: _photoProofUnlocked,
    );
    void openDetails() {
      final realPhotoUrl = kFishRealPhotoUrls[species.id];
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _FishSpeciesDetailScreen(
            species: species,
            status: status,
            realPhotoUrl: _fullUnlocked ? realPhotoUrl : null,
            onOpenMap: onOpenMap,
          ),
        ),
      );
    }

    return Semantics(
      container: true,
      excludeSemantics: true,
      label: semanticsLabel,
      enabled: _basicUnlocked,
      button: _basicUnlocked,
      onTap: _basicUnlocked ? openDetails : null,
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: _basicUnlocked ? 2 : 0,
        child: InkWell(
          onTap: _basicUnlocked ? openDetails : null,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      numberLabel,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: colorScheme.primary,
                          ),
                    ),
                    const Spacer(),
                    Tooltip(
                      message: FishDiscoveryCopy.statusLabel(status),
                      child: Icon(
                        _fullUnlocked
                            ? Icons.verified
                            : _basicUnlocked
                                ? Icons.lock_open
                                : Icons.lock,
                        size: 15,
                        color: _fullUnlocked
                            ? Colors.amber.shade700
                            : _basicUnlocked
                                ? colorScheme.primary
                                : colorScheme.outline,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Center(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _FishArtwork(
                          discovered: _basicUnlocked,
                          colorUnlocked: _colorIconUnlocked,
                          imagePath: species.imageUrl,
                          silhouettePath: species.silhouetteUrl,
                          colorScheme: colorScheme,
                          cacheWidth: fishCatalogArtworkCacheWidth(
                            MediaQuery.devicePixelRatioOf(context),
                          ),
                          cacheHeight: fishCatalogArtworkCacheHeight(
                            MediaQuery.devicePixelRatioOf(context),
                          ),
                        ),
                        if (_photoProofUnlocked)
                          Positioned(
                            left: -4,
                            top: -4,
                            child: _PhotoProofBadge(colorScheme: colorScheme),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _basicUnlocked ? species.displayLocalName : '???',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color:
                                  _basicUnlocked ? null : colorScheme.outline,
                              fontStyle:
                                  _basicUnlocked ? null : FontStyle.italic,
                            ),
                      ),
                    ),
                    if (_basicUnlocked)
                      Icon(
                        _photoProofUnlocked ? Icons.phishing : Icons.check,
                        size: 15,
                        color: _photoProofUnlocked
                            ? Colors.deepOrange
                            : colorScheme.primary,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  status.labelZh,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: _statusColor(colorScheme),
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _statusColor(ColorScheme colorScheme) {
    switch (status) {
      case FishDiscoveryStatus.unknown:
        return colorScheme.outline;
      case FishDiscoveryStatus.encountered:
        return colorScheme.secondary;
      case FishDiscoveryStatus.gameCaught:
        return colorScheme.primary;
      case FishDiscoveryStatus.verifiedRealCatch:
        return Colors.amber.shade800;
    }
  }
}

String _speciesNumberLabel(String id) {
  final match = RegExp(r'(\d+)').firstMatch(id);
  final number = match?.group(1) ?? id.replaceAll(RegExp(r'[^0-9]'), '');
  final padded = number.isEmpty ? id : number.padLeft(3, '0');
  return '#$padded';
}

/// Returns the only artwork that a catalog card needs for its current state.
/// Locked cards must not decode the full-color fish image just to grayscale it.
String? fishArtworkAssetPath({
  required bool discovered,
  required String? imagePath,
  required String? silhouettePath,
}) {
  return discovered ? imagePath : silhouettePath;
}

/// Catalog cards use transparent fish art so the image itself does not add a
/// white square behind the game UI. Local-name badge files only have a
/// numbered transparent fallback, while standard badge files have a matching
/// descriptor-based transparent asset.
String? fishCatalogArtworkAssetPath({
  required bool discovered,
  required String? imagePath,
  required String? silhouettePath,
}) {
  final selected = fishArtworkAssetPath(
    discovered: discovered,
    imagePath: imagePath,
    silhouettePath: silhouettePath,
  );
  return fishGameArtworkAssetPath(selected);
}

/// Keep grid cards from decoding the full-resolution catalog artwork.
///
/// Detail pages intentionally do not use this cap because they are the place
/// where the player inspects a fish closely.
int fishCatalogArtworkCacheWidth(double devicePixelRatio) =>
    (150 * devicePixelRatio).round().clamp(180, 480).toInt();

int fishCatalogArtworkCacheHeight(double devicePixelRatio) =>
    (135 * devicePixelRatio).round().clamp(162, 432).toInt();

class _FishArtwork extends StatelessWidget {
  const _FishArtwork({
    required this.discovered,
    required this.colorUnlocked,
    required this.imagePath,
    required this.silhouettePath,
    required this.colorScheme,
    required this.cacheWidth,
    required this.cacheHeight,
  });

  final bool discovered;
  final bool colorUnlocked;
  final String? imagePath;
  final String? silhouettePath;
  final ColorScheme colorScheme;
  final int cacheWidth;
  final int cacheHeight;

  @override
  Widget build(BuildContext context) {
    final previewPath = fishCatalogArtworkAssetPath(
      discovered: discovered,
      imagePath: imagePath,
      silhouettePath: silhouettePath,
    );
    if (previewPath != null && previewPath.startsWith('assets/')) {
      return ColorFiltered(
        colorFilter: colorUnlocked
            ? const ColorFilter.mode(Colors.transparent, BlendMode.dst)
            : const ColorFilter.matrix(<double>[
                0.2126,
                0.7152,
                0.0722,
                0,
                0,
                0.2126,
                0.7152,
                0.0722,
                0,
                0,
                0.2126,
                0.7152,
                0.0722,
                0,
                0,
                0,
                0,
                0,
                1,
                0,
              ]),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 150, maxHeight: 135),
          child: Image.asset(
            previewPath,
            fit: BoxFit.contain,
            cacheWidth: cacheWidth,
            cacheHeight: cacheHeight,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, __, ___) => _fallbackIcon(),
          ),
        ),
      );
    }

    return _fallbackIcon();
  }

  Widget _fallbackIcon() {
    final color = colorUnlocked
        ? colorScheme.primary
        : discovered
            ? colorScheme.outline
            : colorScheme.outlineVariant;
    return SizedBox(
      width: 94,
      height: 78,
      child: CustomPaint(
        painter: _LockedFishSilhouettePainter(
          fillColor: color.withValues(alpha: colorUnlocked ? 0.82 : 0.56),
          lineColor: color.withValues(alpha: 0.88),
        ),
      ),
    );
  }
}

class _LockedFishSilhouettePainter extends CustomPainter {
  const _LockedFishSilhouettePainter({
    required this.fillColor,
    required this.lineColor,
  });

  final Color fillColor;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final fill = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Fish silhouette
    final body = Path()
      ..moveTo(w * 0.10, h * 0.52)
      ..cubicTo(w * 0.28, h * 0.18, w * 0.63, h * 0.16, w * 0.82, h * 0.46)
      ..cubicTo(w * 0.66, h * 0.82, w * 0.28, h * 0.82, w * 0.10, h * 0.52)
      ..close();
    final tail = Path()
      ..moveTo(w * 0.82, h * 0.46)
      ..lineTo(w * 0.98, h * 0.24)
      ..lineTo(w * 0.94, h * 0.52)
      ..lineTo(w * 0.98, h * 0.78)
      ..lineTo(w * 0.82, h * 0.58)
      ..close();
    final topFin = Path()
      ..moveTo(w * 0.44, h * 0.25)
      ..quadraticBezierTo(w * 0.55, h * 0.02, w * 0.64, h * 0.30)
      ..close();
    final bottomFin = Path()
      ..moveTo(w * 0.47, h * 0.68)
      ..quadraticBezierTo(w * 0.56, h * 0.94, w * 0.66, h * 0.66)
      ..close();

    canvas.drawPath(tail, fill);
    canvas.drawPath(body, fill);
    canvas.drawPath(topFin, fill);
    canvas.drawPath(bottomFin, fill);

    // Eye
    canvas.drawCircle(Offset(w * 0.26, h * 0.43), 3.2, stroke);

    // Big "?" centred in fish body — unmistakable locked state
    final qp = Path();
    final cx = w * 0.50;
    final cy = h * 0.52;
    final qs = w * 0.21;
    // Question mark curve (top arc)
    qp.moveTo(cx + qs * 0.3, cy - qs * 0.55);
    qp.quadraticBezierTo(cx + qs * 0.55, cy - qs * 0.9, cx, cy - qs * 0.9);
    qp.quadraticBezierTo(
        cx - qs * 0.55, cy - qs * 0.9, cx - qs * 0.3, cy - qs * 0.6);
    qp.quadraticBezierTo(cx - qs * 0.05, cy - qs * 0.35, cx, cy - qs * 0.1);
    // Stem
    qp.lineTo(cx, cy + qs * 0.1);
    // Dot
    final dotPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy + qs * 0.35), qs * 0.13, dotPaint);

    final qStroke = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(qp, qStroke);

    // Subtle outline on silhouette
    canvas.drawPath(tail, stroke);
    canvas.drawPath(body, stroke);
    canvas.drawPath(topFin, stroke);
    canvas.drawPath(bottomFin, stroke);
  }

  @override
  bool shouldRepaint(covariant _LockedFishSilhouettePainter oldDelegate) =>
      oldDelegate.fillColor != fillColor || oldDelegate.lineColor != lineColor;
}

class _PhotoProofBadge extends StatelessWidget {
  const _PhotoProofBadge({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.amber.shade600,
        border: Border.all(color: colorScheme.surface, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Tooltip(
        message: '真實釣獲相片',
        child: Icon(
          Icons.phishing,
          size: 17,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _FishSpeciesDetailScreen extends StatelessWidget {
  const _FishSpeciesDetailScreen({
    required this.species,
    required this.status,
    required this.realPhotoUrl,
    this.onOpenMap,
  });

  final FishSpecies species;
  final FishDiscoveryStatus status;
  final String? realPhotoUrl;
  final VoidCallback? onOpenMap;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(species.displayLocalName)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FishRealPhoto(
              realPhotoUrl: realPhotoUrl,
              fallbackAsset: fishCatalogArtworkAssetPath(
                discovered: status.showsFullInfo,
                imagePath: species.imageUrl,
                silhouettePath: species.silhouetteUrl,
              ),
            ),
            const SizedBox(height: 16),
            _InfoTile(
              title: '解鎖狀態',
              value: FishDiscoveryCopy.statusLabel(status),
            ),
            _InfoTile(title: '本地名', value: species.displayLocalName),
            if (species.commonNameZh.trim() != species.displayLocalName)
              _InfoTile(title: '正式名', value: species.commonNameZh.trim()),
            _InfoTile(title: '稀有度', value: 'Rank ${species.rarityRank}'),
            _InfoTile(title: '出現提示', value: species.habitatZh ?? '香港近岸及外海水域'),
            if (status.showsFullInfo) ...[
              _InfoTile(title: '學名', value: species.scientificName ?? '待補'),
              _InfoTile(title: '英文名', value: species.commonNameEn ?? '待補'),
              _InfoTile(title: '危險性', value: _dangerLabel(species.dangerLevel)),
              _InfoTile(title: '棲息地', value: species.habitatZh ?? '待補'),
              _InfoTile(title: '描述', value: species.descriptionZh ?? '待補'),
            ] else
              _InfoTile(
                title: '下一步',
                value: FishDiscoveryCopy.detailHint(status),
              ),
          ],
        ),
      ),
    );
  }

  String _dangerLabel(String level) {
    switch (level) {
      case 'high':
        return '高';
      case 'medium':
        return '中';
      case 'low':
        return '低';
      default:
        return '待確認';
    }
  }
}

class _FishRealPhoto extends StatelessWidget {
  const _FishRealPhoto({
    required this.realPhotoUrl,
    required this.fallbackAsset,
  });

  final String? realPhotoUrl;
  final String? fallbackAsset;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(16);

    if (realPhotoUrl != null && realPhotoUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Image.network(
            realPhotoUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _fallback(borderRadius),
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const Center(child: CircularProgressIndicator());
            },
          ),
        ),
      );
    }

    return _fallback(borderRadius);
  }

  Widget _fallback(BorderRadius borderRadius) {
    if (fallbackAsset != null && fallbackAsset!.startsWith('assets/')) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Image.asset(fallbackAsset!, fit: BoxFit.contain),
        ),
      );
    }

    return Container(
      height: 180,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        color: Colors.black12,
      ),
      child: const Center(child: Icon(Icons.image_not_supported, size: 44)),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, size: 48),
          const SizedBox(height: 12),
          const Text('圖鑑暫時無法載入'),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('重試'),
          ),
        ],
      ),
    );
  }
}
