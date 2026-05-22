import 'package:flutter/material.dart';

import '../data/fish_species_repository.dart';
import '../data/sample_fish_species_repository.dart';
import '../domain/fish_species.dart';

class FishEncyclopediaScreen extends StatefulWidget {
  const FishEncyclopediaScreen({
    super.key,
    this.repository,
  });

  final FishSpeciesRepository? repository;

  @override
  State<FishEncyclopediaScreen> createState() => _FishEncyclopediaScreenState();
}

class _FishEncyclopediaScreenState extends State<FishEncyclopediaScreen> {
  late Future<List<FishSpecies>> _speciesFuture;
  var _isRefreshing = false;
  var _statusText = '正在載入離線圖鑑…';

  @override
  void initState() {
    super.initState();
    _speciesFuture = _loadSpecies();
  }

  Future<List<FishSpecies>> _loadSpecies({bool forceRefresh = false}) async {
    setStateIfMounted(() {
      _isRefreshing = forceRefresh;
      _statusText = forceRefresh ? '正在重新同步圖鑑…' : '正在載入離線圖鑑…';
    });

    final repository = widget.repository ?? const SampleFishSpeciesRepository();
    final species = await repository.getSpecies(forceRefresh: forceRefresh);

    setStateIfMounted(() {
      _isRefreshing = false;
      _statusText = '已載入 ${species.length} 種魚類（Web MVP：本地快取 / 樣本資料，可離線瀏覽）';
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
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _ErrorState(onRetry: _refresh);
          }

          final species = snapshot.data ?? const <FishSpecies>[];
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _EncyclopediaHeader(
                  statusText: _statusText,
                  totalSpecies: species.length,
                  unlockedSpecies: _unlockedCount(species),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverLayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount =
                        _gridColumns(constraints.crossAxisExtent);
                    return SliverGrid.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: crossAxisCount >= 4 ? 0.92 : 0.82,
                      ),
                      itemCount: species.length,
                      itemBuilder: (context, index) {
                        final item = species[index];
                        return _FishSpeciesCard(
                          species: item,
                          unlocked: _isUnlocked(index),
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
    if (width >= 1100) return 5;
    if (width >= 840) return 4;
    if (width >= 560) return 3;
    return 2;
  }

  int _unlockedCount(List<FishSpecies> species) =>
      species.asMap().entries.where((entry) => _isUnlocked(entry.key)).length;

  bool _isUnlocked(int index) => index < 2;
}

class _EncyclopediaHeader extends StatelessWidget {
  const _EncyclopediaHeader({
    required this.statusText,
    required this.totalSpecies,
    required this.unlockedSpecies,
  });

  final String statusText;
  final int totalSpecies;
  final int unlockedSpecies;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer,
            colorScheme.secondaryContainer
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FisherGO Web 圖鑑',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          const Text('先做可在 Chrome 使用的離線優先 Web App；Android 之後再補。'),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MetricChip(label: '魚種', value: '$totalSpecies'),
              _MetricChip(label: '已解鎖', value: '$unlockedSpecies'),
              const _MetricChip(label: '模式', value: 'Web MVP'),
            ],
          ),
          const SizedBox(height: 14),
          Text(statusText, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label：$value'),
      avatar: const Icon(Icons.water, size: 18),
    );
  }
}

class _FishSpeciesCard extends StatelessWidget {
  const _FishSpeciesCard({required this.species, required this.unlocked});

  final FishSpecies species;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dangerColor = _dangerColor(species.dangerLevel, colorScheme);

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: unlocked ? 2 : 0,
      child: InkWell(
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: unlocked
                          ? colorScheme.primaryContainer
                          : colorScheme.surfaceContainerHighest,
                    ),
                    child: Icon(
                      unlocked ? Icons.set_meal : Icons.question_mark,
                      size: unlocked ? 58 : 48,
                      color:
                          unlocked ? colorScheme.primary : colorScheme.outline,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      unlocked ? species.commonNameZh : '未解鎖魚種',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  Icon(
                    unlocked ? Icons.lock_open : Icons.lock,
                    size: 18,
                    color: unlocked ? colorScheme.primary : colorScheme.outline,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                unlocked
                    ? (species.scientificName ?? species.commonNameEn ?? '學名待補')
                    : '釣獲後顯示相片、學名與習性',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              if (unlocked) ...[
                Text(
                  species.habitatZh ?? '棲息地資料待補',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
              ],
              Chip(
                visualDensity: VisualDensity.compact,
                backgroundColor: dangerColor.withValues(alpha: 0.14),
                label: Text(
                  unlocked
                      ? '危險性：${_dangerLabel(species.dangerLevel)}'
                      : '剪影模式',
                  style: TextStyle(
                      color: unlocked ? dangerColor : colorScheme.outline),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _dangerColor(String level, ColorScheme colorScheme) {
    switch (level) {
      case 'high':
        return Colors.red.shade700;
      case 'medium':
        return Colors.orange.shade800;
      case 'low':
        return Colors.green.shade700;
      default:
        return colorScheme.outline;
    }
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
