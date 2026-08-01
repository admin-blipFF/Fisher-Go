import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/admin/admin_ops_service.dart';
import '../../../core/admin/fishing_spot_content_draft.dart';
import '../../../features/fish/data/sample_fish_species_data_source.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  static const String _buildTime =
      String.fromEnvironment('BUILD_TIME', defaultValue: 'dev');

  final _announcementTitle = TextEditingController();
  final _announcementBody = TextEditingController();
  final _announcementCoins = TextEditingController(text: '0');
  final _eventTitle = TextEditingController();
  final _eventDescription = TextEditingController();
  final _eventMultiplier = TextEditingController(text: '2');
  final _grantEmail = TextEditingController();
  final _grantAmount = TextEditingController(text: '100');
  final _grantReason = TextEditingController(text: '活動獎勵');
  bool _loading = false;
  bool _isAdmin = false;
  bool _moderationLoading = false;
  List<Map<String, dynamic>> _moderationSpots = const [];
  bool _catchModerationLoading = false;
  List<Map<String, dynamic>> _moderationCatches = const [];
  bool _retentionLoading = false;
  List<AnalyticsRetentionCohort> _retentionReport = const [];

  // Fish species list for dropdown
  late List<_FishOption> _fishOptions;
  String? _selectedFishId;

  @override
  void initState() {
    super.initState();
    _fishOptions = const SampleFishSpeciesDataSource()
        .loadSpecies()
        .map((s) => _FishOption(
              id: s.id,
              label: '${s.id.replaceFirst('fish-', '#')} ${s.displayLocalName}',
            ))
        .toList();
    unawaited(_loadModerationSpots());
  }

  @override
  void dispose() {
    _announcementTitle.dispose();
    _announcementBody.dispose();
    _announcementCoins.dispose();
    _eventTitle.dispose();
    _eventDescription.dispose();
    _eventMultiplier.dispose();
    _grantEmail.dispose();
    _grantAmount.dispose();
    _grantReason.dispose();
    super.dispose();
  }

  Future<void> _run(String success, Future<void> Function() action) async {
    setState(() => _loading = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(success)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('操作失敗：$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin 營運後台')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('Build 時間'),
              subtitle: Text(_buildTime),
              dense: true,
            ),
          ),
          const SizedBox(height: 12),
          _section(
            title: '新增公告',
            icon: Icons.campaign,
            children: [
              _field(_announcementTitle, '公告標題'),
              _field(_announcementBody, '公告內容', maxLines: 4),
              _field(_announcementCoins, '公告獎勵金幣',
                  keyboardType: TextInputType.number),
              FilledButton.icon(
                onPressed: _loading
                    ? null
                    : () => _run('公告已新增', () async {
                          await AdminOpsService.createAnnouncement(
                            title: _announcementTitle.text.trim(),
                            body: _announcementBody.text.trim(),
                            coinReward:
                                int.tryParse(_announcementCoins.text) ?? 0,
                          );
                          _announcementTitle.clear();
                          _announcementBody.clear();
                          _announcementCoins.text = '0';
                        }),
                icon: const Icon(Icons.send),
                label: const Text('發布公告'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _section(
            title: '舉行活動 / 加大魚種出現率',
            icon: Icons.local_activity,
            children: [
              _field(_eventTitle, '活動名稱'),
              _field(_eventDescription, '活動說明', maxLines: 3),
              // Fish species dropdown
              DropdownButtonFormField<String>(
                initialValue: _selectedFishId,
                decoration: InputDecoration(
                  labelText: '選擇加成魚種',
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.grey[900],
                ),
                dropdownColor: Colors.grey[850],
                isExpanded: true,
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('全部魚種（隨機）',
                        style: TextStyle(color: Colors.white70)),
                  ),
                  ..._fishOptions.map((f) => DropdownMenuItem(
                        value: f.id,
                        child: Text(f.label,
                            style: const TextStyle(color: Colors.white),
                            overflow: TextOverflow.ellipsis),
                      )),
                ],
                onChanged: (v) => setState(() => _selectedFishId = v),
              ),
              const SizedBox(height: 8),
              _field(_eventMultiplier, '出現率倍率，例如：3',
                  keyboardType: TextInputType.number),
              FilledButton.icon(
                onPressed: _loading
                    ? null
                    : () => _run('活動已建立，魚種倍率已啟用', () async {
                          final fishLabel = _selectedFishId != null
                              ? _fishOptions
                                  .firstWhere((f) => f.id == _selectedFishId,
                                      orElse: () =>
                                          const _FishOption(id: '', label: ''))
                                  .label
                              : null;
                          await AdminOpsService.createEvent(
                            title: _eventTitle.text.trim(),
                            description: _eventDescription.text.trim(),
                            fishId: _selectedFishId,
                            fishName: fishLabel ?? _eventTitle.text.trim(),
                            multiplier:
                                double.tryParse(_eventMultiplier.text) ?? 2.0,
                          );
                          _eventTitle.clear();
                          _eventDescription.clear();
                          _selectedFishId = null;
                          _eventMultiplier.text = '2';
                        }),
                icon: const Icon(Icons.trending_up),
                label: const Text('建立活動'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _section(
            title: '派發金錢',
            icon: Icons.payments,
            children: [
              _field(_grantEmail, '指定玩家 Email；留空 = 全部玩家'),
              _field(_grantAmount, '金幣數量', keyboardType: TextInputType.number),
              _field(_grantReason, '派發原因'),
              FilledButton.icon(
                onPressed: _loading
                    ? null
                    : () => _run('派錢紀錄已建立', () async {
                          await AdminOpsService.grantCoins(
                            targetEmail: _grantEmail.text.trim().isEmpty
                                ? null
                                : _grantEmail.text.trim(),
                            amount: int.tryParse(_grantAmount.text) ?? 0,
                            reason: _grantReason.text.trim().isEmpty
                                ? 'Admin 派發'
                                : _grantReason.text.trim(),
                          );
                          _grantEmail.clear();
                          _grantAmount.text = '100';
                          _grantReason.text = '活動獎勵';
                        }),
                icon: const Icon(Icons.card_giftcard),
                label: const Text('派發'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isAdmin) ...[
            _buildFishingSpotModerationSection(),
            const SizedBox(height: 12),
            _buildCatchModerationSection(),
            const SizedBox(height: 12),
            _buildRetentionSection(),
          ],
          const SizedBox(height: 12),
          const Text(
            '安全規則：只有 Supabase admin_users 表內的 email 可進入及寫入。派給全部玩家的金幣會在玩家登入後自動領取到本機錢包。',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Future<void> _loadModerationSpots() async {
    final isAdmin = await AdminOpsService.isCurrentUserAdmin();
    if (!mounted) return;
    if (!isAdmin) {
      setState(() {
        _isAdmin = false;
        _moderationSpots = const [];
      });
      return;
    }

    setState(() {
      _isAdmin = true;
      _moderationLoading = true;
      _catchModerationLoading = true;
      _retentionLoading = true;
    });
    unawaited(_loadRetentionReport());
    unawaited(_loadModerationCatches());
    try {
      final spots = await AdminOpsService.loadFishingSpotsForModeration();
      if (!mounted) return;
      setState(() => _moderationSpots = spots);
    } finally {
      if (mounted) setState(() => _moderationLoading = false);
    }
  }

  Future<void> _loadModerationCatches() async {
    try {
      final catches = await AdminOpsService.loadCatchesForModeration();
      if (!mounted) return;
      setState(() => _moderationCatches = catches);
    } catch (_) {
      if (!mounted) return;
      setState(() => _moderationCatches = const []);
    } finally {
      if (mounted) setState(() => _catchModerationLoading = false);
    }
  }

  Future<void> _loadRetentionReport() async {
    try {
      final today = DateTime.now().toUtc();
      final report = await AdminOpsService.loadRetentionReport(
        fromDate: today.subtract(const Duration(days: 37)),
        toDate: today.subtract(const Duration(days: 7)),
      );
      if (!mounted) return;
      setState(() => _retentionReport = report);
    } catch (_) {
      if (!mounted) return;
      setState(() => _retentionReport = const []);
    } finally {
      if (mounted) setState(() => _retentionLoading = false);
    }
  }

  Widget _buildRetentionSection() {
    final rows = _retentionReport.reversed.take(14).toList(growable: false);
    return _section(
      title: '玩家留存（D2 / D7）',
      icon: Icons.insights,
      children: [
        if (_retentionLoading)
          const LinearProgressIndicator(minHeight: 2)
        else if (rows.isEmpty)
          const Text('目前沒有可用的留存資料', style: TextStyle(color: Colors.white70))
        else
          ...rows.map(
            (row) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(
                '${row.cohortDate.year}/${row.cohortDate.month}/${row.cohortDate.day} · ${row.cohortSize} 名新玩家',
              ),
              subtitle: Text(
                'D2 ${row.day2Returners} 人（${row.day2Rate.toStringAsFixed(1)}%）  ·  D7 ${row.day7Returners} 人（${row.day7Rate.toStringAsFixed(1)}%）',
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCatchModerationSection() {
    return _section(
      title: '真實釣獲審核',
      icon: Icons.fact_check,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '未審核的相片不會出現在公開排行榜。',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            IconButton(
              tooltip: '重新載入真實釣獲',
              onPressed:
                  _catchModerationLoading ? null : _loadModerationCatches,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        if (_catchModerationLoading) const LinearProgressIndicator(),
        if (!_catchModerationLoading && _moderationCatches.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('目前沒有待審核的真實釣獲。'),
          ),
        ..._moderationCatches.map(_buildCatchModerationRow),
      ],
    );
  }

  Widget _buildCatchModerationRow(Map<String, dynamic> catchRow) {
    final id = catchRow['id']?.toString() ?? '';
    final species = catchRow['species_name']?.toString().trim();
    final status = catchRow['moderation_status']?.toString() ?? 'pending';
    final caughtAt = DateTime.tryParse(catchRow['caught_at']?.toString() ?? '');
    final photoUrl = catchRow['photo_url']?.toString();
    const statuses = ['pending', 'approved', 'rejected', 'suspended'];

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: photoUrl == null || photoUrl.isEmpty
                      ? const Icon(Icons.photo_outlined, color: Colors.white54)
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            photoUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.broken_image_outlined,
                              color: Colors.white54,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      species?.isNotEmpty == true ? species! : '未知魚種',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      caughtAt == null
                          ? id
                          : '${caughtAt.year}/${caughtAt.month}/${caughtAt.day} ${caughtAt.hour.toString().padLeft(2, '0')}:${caughtAt.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: statuses.contains(status) ? status : 'pending',
            decoration: const InputDecoration(
              labelText: '審核狀態',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final value in statuses)
                DropdownMenuItem(value: value, child: Text(value)),
            ],
            onChanged: _loading
                ? null
                : (value) {
                    if (value == null || value == status) return;
                    unawaited(_updateCatchModeration(catchRow, value));
                  },
          ),
          const Divider(height: 18),
        ],
      ),
    );
  }

  Future<void> _updateCatchModeration(
    Map<String, dynamic> catchRow,
    String status,
  ) async {
    final reason = switch (status) {
      'approved' => '相片及資料已審核',
      'rejected' => '相片或資料未通過審核',
      'suspended' => '暫停公開此真實釣獲',
      _ => null,
    };
    await _run('真實釣獲審核狀態已更新', () async {
      await AdminOpsService.moderateCatch(
        id: catchRow['id'].toString(),
        moderationStatus: status,
        reason: reason,
      );
      await _loadModerationCatches();
    });
  }

  Widget _buildFishingSpotModerationSection() {
    return _section(
      title: '釣點審核與停用',
      icon: Icons.location_searching,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '只有已驗證、啟用及公開的釣點會出現在玩家地圖。',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            IconButton(
              tooltip: '重新載入釣點',
              onPressed: _moderationLoading ? null : _loadModerationSpots,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        if (_moderationLoading) const LinearProgressIndicator(),
        if (!_moderationLoading && _moderationSpots.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('目前沒有可供審核的遠端釣點。'),
          ),
        ..._moderationSpots.map(_buildFishingSpotModerationRow),
      ],
    );
  }

  Widget _buildFishingSpotModerationRow(Map<String, dynamic> spot) {
    final id = spot['id']?.toString() ?? '';
    final name = spot['name_zh']?.toString().trim();
    final status = spot['verification_status']?.toString() ?? 'draft';
    final active = spot['active'] as bool? ?? false;
    final publicAccess = spot['public_access'] as bool? ?? false;
    const statuses = [
      'draft',
      'communityReported',
      'verified',
      'suspended',
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: Icon(
              active && publicAccess ? Icons.place : Icons.place_outlined,
              color: active && publicAccess ? Colors.tealAccent : Colors.grey,
            ),
            title: Text(name?.isNotEmpty == true ? name! : id),
            subtitle: Text(id),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _loading
                  ? null
                  : () => unawaited(_editFishingSpotContent(spot)),
              icon: const Icon(Icons.tune),
              label: const Text('編輯棲地及魚種權重'),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: statuses.contains(status) ? status : 'draft',
                  decoration: const InputDecoration(
                    labelText: '審核狀態',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final value in statuses)
                      DropdownMenuItem(value: value, child: Text(value)),
                  ],
                  onChanged: _loading
                      ? null
                      : (value) {
                          if (value == null || value == status) return;
                          unawaited(_updateFishingSpotModeration(
                            spot,
                            verificationStatus: value,
                          ));
                        },
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  Switch(
                    value: active,
                    onChanged: _loading
                        ? null
                        : (value) => unawaited(
                              _updateFishingSpotModeration(
                                spot,
                                active: value,
                              ),
                            ),
                  ),
                  const Text('啟用', style: TextStyle(fontSize: 11)),
                ],
              ),
              Column(
                children: [
                  Switch(
                    value: publicAccess,
                    onChanged: _loading
                        ? null
                        : (value) => unawaited(
                              _updateFishingSpotModeration(
                                spot,
                                publicAccess: value,
                              ),
                            ),
                  ),
                  const Text('公開', style: TextStyle(fontSize: 11)),
                ],
              ),
            ],
          ),
          const Divider(height: 1),
        ],
      ),
    );
  }

  Future<void> _editFishingSpotContent(Map<String, dynamic> spot) async {
    final tagController = TextEditingController(
      text: (spot['habitat_tags'] as List?)?.whereType<String>().join(', ') ??
          '',
    );
    final rawWeights = spot['species_weights'];
    final initialWeights = <String, num>{};
    if (rawWeights is Map) {
      for (final entry in rawWeights.entries) {
        if (entry.value is num) {
          initialWeights[entry.key.toString()] = entry.value as num;
        }
      }
    }
    final weightController = TextEditingController(
      text: FishingSpotContentDraft.formatSpeciesWeights(initialWeights),
    );

    final draft = await showDialog<FishingSpotContentDraft>(
      context: context,
      builder: (dialogContext) {
        String? error;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('編輯棲地及魚種權重'),
            content: SizedBox(
              width: 460,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: tagController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'habitat_tags',
                        hintText: 'nearshore, pier, tsing-ma-waters',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: weightController,
                      maxLines: 6,
                      keyboardType: TextInputType.multiline,
                      decoration: const InputDecoration(
                        labelText: 'species_weights',
                        hintText: 'fish-103 = 4\nfish-109 = 1.5',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 8),
                      Text(error!, style: TextStyle(color: Colors.redAccent)),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('取消'),
              ),
              FilledButton.icon(
                onPressed: () {
                  try {
                    final next = FishingSpotContentDraft.fromText(
                      habitatTags: tagController.text,
                      speciesWeights: weightController.text,
                    );
                    Navigator.of(dialogContext).pop(next);
                  } on FormatException catch (exception) {
                    setDialogState(() => error = exception.message);
                  }
                },
                icon: const Icon(Icons.save),
                label: const Text('儲存內容'),
              ),
            ],
          ),
        );
      },
    );
    tagController.dispose();
    weightController.dispose();
    if (!mounted || draft == null) return;

    await _run('釣點棲地及魚種權重已更新', () async {
      await AdminOpsService.updateFishingSpotContent(
        id: spot['id'].toString(),
        habitatTags: draft.habitatTags,
        speciesWeights: draft.speciesWeights,
      );
      await _loadModerationSpots();
    });
  }

  Future<void> _updateFishingSpotModeration(
    Map<String, dynamic> spot, {
    bool? active,
    String? verificationStatus,
    bool? publicAccess,
  }) async {
    await _run('釣點審核狀態已更新', () async {
      await AdminOpsService.moderateFishingSpot(
        id: spot['id'].toString(),
        active: active ?? spot['active'] as bool? ?? false,
        verificationStatus: verificationStatus ??
            spot['verification_status']?.toString() ??
            'draft',
        publicAccess: publicAccess ?? spot['public_access'] as bool? ?? false,
      );
      await _loadModerationSpots();
    });
  }

  Widget _section(
      {required String title,
      required IconData icon,
      required List<Widget> children}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Icon(icon),
              const SizedBox(width: 8),
              Text(title, style: Theme.of(context).textTheme.titleLarge)
            ]),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController controller, String label,
      {int maxLines = 1, TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
            labelText: label, border: const OutlineInputBorder()),
      ),
    );
  }
}

class _FishOption {
  final String id;
  final String label;
  const _FishOption({required this.id, required this.label});
}
