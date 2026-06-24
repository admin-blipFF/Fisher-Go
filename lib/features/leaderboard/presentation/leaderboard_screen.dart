import 'package:flutter/material.dart';

import '../../fish/data/sample_fish_species_data_source.dart';
import '../../fish/domain/fish_collection_service.dart';
import '../../fish/domain/fish_collection_status.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late Future<_CompetitionSnapshot> _snapshotFuture;

  @override
  void initState() {
    super.initState();
    _snapshotFuture = _loadSnapshot();
  }

  Future<_CompetitionSnapshot> _loadSnapshot() async {
    final species = const SampleFishSpeciesDataSource().loadSpecies();
    final collection = await FishCollectionService.loadAll();
    final speciesById = {for (final fish in species) fish.id: fish};

    final verifiedEntries = collection.values
        .where((entry) => entry.status == FishDiscoveryStatus.verifiedRealCatch)
        .toList(growable: false);

    final rows = verifiedEntries.map((entry) {
      final fish = speciesById[entry.fishId];
      return _VerifiedCatchRow(
        fishId: entry.fishId,
        fishName: fish?.displayNameLocalSlashCommon ?? entry.fishId,
        rarityRank: fish?.rarityRank ?? 1,
        bestLengthCm: entry.bestLengthCm,
        verifiedAt: entry.firstRealCaughtAt,
        photoPath: entry.realCatchPhotoPath,
      );
    }).toList(growable: false)
      ..sort((a, b) {
        final lengthCompare =
            (b.bestLengthCm ?? 0).compareTo(a.bestLengthCm ?? 0);
        if (lengthCompare != 0) return lengthCompare;
        final rarityCompare = b.rarityRank.compareTo(a.rarityRank);
        if (rarityCompare != 0) return rarityCompare;
        return a.fishName.compareTo(b.fishName);
      });

    final gameCaughtCount = collection.values
        .where((entry) => entry.status == FishDiscoveryStatus.gameCaught)
        .length;

    return _CompetitionSnapshot(
      totalSpecies: species.length,
      verifiedRows: rows,
      gameCaughtCount: gameCaughtCount,
    );
  }

  Future<void> _refresh() async {
    setState(() => _snapshotFuture = _loadSnapshot());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('比賽活動'),
        actions: [
          IconButton(
            tooltip: '重新整理',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<_CompetitionSnapshot>(
        future: _snapshotFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _ErrorState(onRetry: _refresh);
          }

          final data = snapshot.data ?? _CompetitionSnapshot.empty();
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _EventHero(snapshot: data),
                const SizedBox(height: 16),
                _RulesCard(snapshot: data),
                const SizedBox(height: 16),
                _VerifiedLeaderboard(rows: data.verifiedRows),
                const SizedBox(height: 16),
                const _ShopHintCard(),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EventHero extends StatelessWidget {
  const _EventHero({required this.snapshot});

  final _CompetitionSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colorScheme.primaryContainer, colorScheme.tertiaryContainer],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '週末真實捕獲盃',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          const Text('只計真實相片驗證魚獲。遊戲刷到只開灰章，不入榜。'),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MetricChip(
                  label: '可參賽', value: '${snapshot.verifiedRows.length}'),
              _MetricChip(label: '灰章魚種', value: '${snapshot.gameCaughtCount}'),
              _MetricChip(label: '總魚種', value: '${snapshot.totalSpecies}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _RulesCard extends StatelessWidget {
  const _RulesCard({required this.snapshot});

  final _CompetitionSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('活動規則', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            const _RuleLine(
                icon: Icons.camera_alt, text: '必須上載真實魚獲相片，才有彩色徽章及比賽資格。'),
            const _RuleLine(
                icon: Icons.catching_pokemon, text: '釣點刷魚只解鎖灰章和基本資料，可用來探索魚種。'),
            const _RuleLine(
                icon: Icons.straighten, text: '排行榜 MVP 先按長度排序；未填長度則按稀有度排序。'),
            const _RuleLine(
                icon: Icons.store, text: '商城道具用於增加刷魚機會，不能直接買入比賽資格。'),
            if (snapshot.verifiedRows.isEmpty) ...[
              const SizedBox(height: 12),
              Text(
                '未有合資格魚獲：到「魚獲」頁新增記錄並附相片，即可開彩章及入榜。',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _VerifiedLeaderboard extends StatelessWidget {
  const _VerifiedLeaderboard({required this.rows});

  final List<_VerifiedCatchRow> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('真實捕獲排行榜', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: Text('暫無已驗證魚獲')),
              )
            else
              ...rows.asMap().entries.map((entry) {
                final rank = entry.key + 1;
                final row = entry.value;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(child: Text('$rank')),
                  title: Text(row.fishName,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    '${row.bestLengthCm == null ? '未填長度' : '${row.bestLengthCm!.toStringAsFixed(1)} cm'}｜稀有度 ${row.rarityRank}\n${_formatDate(row.verifiedAt)}',
                  ),
                  trailing: const Icon(Icons.verified, color: Colors.amber),
                );
              }),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '驗證時間未記錄';
    final mm = value.month.toString().padLeft(2, '0');
    final dd = value.day.toString().padLeft(2, '0');
    return '${value.year}-$mm-$dd';
  }
}

class _ShopHintCard extends StatelessWidget {
  const _ShopHintCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline),
            SizedBox(width: 12),
            Expanded(
              child: Text('下一步可加入限時活動、指定魚種任務、隊伍賽和季票；現階段已先鎖定「真實相片驗證才可參賽」的核心規則。'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RuleLine extends StatelessWidget {
  const _RuleLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
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
      avatar: const Icon(Icons.emoji_events, size: 18),
      label: Text('$label：$value'),
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
          const Icon(Icons.error_outline, size: 40),
          const SizedBox(height: 12),
          const Text('排行榜暫時無法載入'),
          const SizedBox(height: 12),
          FilledButton.tonal(onPressed: onRetry, child: const Text('重試')),
        ],
      ),
    );
  }
}

class _CompetitionSnapshot {
  const _CompetitionSnapshot({
    required this.totalSpecies,
    required this.verifiedRows,
    required this.gameCaughtCount,
  });

  final int totalSpecies;
  final List<_VerifiedCatchRow> verifiedRows;
  final int gameCaughtCount;

  factory _CompetitionSnapshot.empty() => const _CompetitionSnapshot(
        totalSpecies: 0,
        verifiedRows: [],
        gameCaughtCount: 0,
      );
}

class _VerifiedCatchRow {
  const _VerifiedCatchRow({
    required this.fishId,
    required this.fishName,
    required this.rarityRank,
    this.bestLengthCm,
    this.verifiedAt,
    this.photoPath,
  });

  final String fishId;
  final String fishName;
  final int rarityRank;
  final double? bestLengthCm;
  final DateTime? verifiedAt;
  final String? photoPath;
}
