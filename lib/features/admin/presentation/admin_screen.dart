import 'package:flutter/material.dart';

import '../../../core/admin/admin_ops_service.dart';
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
          const Text(
            '安全規則：只有 Supabase admin_users 表內的 email 可進入及寫入。派給全部玩家的金幣會在玩家登入後自動領取到本機錢包。',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
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
