import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../data/profile_wallet_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _profileBoxName = 'profile_customization';

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isProfileLoading = true;

  late _AvatarProfileState _avatarState;
  List<Map<String, dynamic>> _coinHistory = const [];

  @override
  void initState() {
    super.initState();
    _avatarState = _AvatarProfileState.initial();
    _loadAvatarState();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadAvatarState() async {
    final box = await Hive.openBox(_profileBoxName);
    final saved = box.get('avatar_state');
    final history = await ProfileWalletService.getCoinHistory();
    if (!mounted) return;

    if (saved is Map) {
      setState(() {
        _avatarState = _AvatarProfileState.fromMap(Map<String, dynamic>.from(saved));
        _coinHistory = history;
        _isProfileLoading = false;
      });
      return;
    }

    setState(() {
      _coinHistory = history;
      _isProfileLoading = false;
    });
  }

  Future<void> _saveAvatarState() async {
    final box = await Hive.openBox(_profileBoxName);
    final existingRaw = box.get('avatar_state');
    final existing = existingRaw is Map
        ? Map<String, dynamic>.from(existingRaw)
        : <String, dynamic>{};
    final merged = _avatarState.toMap()..addAll({
      if (existing['coinHistory'] != null) 'coinHistory': existing['coinHistory'],
    });
    await box.put('avatar_state', merged);
    final history = await ProfileWalletService.getCoinHistory();
    if (mounted) {
      setState(() => _coinHistory = history);
    }
  }

  Future<void> _signIn() async {
    if (!SupabaseConfig.isConfigured) return;
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('登入成功')),
      );
      setState(() {});
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('登入失敗：${e.message}')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signUp() async {
    if (!SupabaseConfig.isConfigured) return;
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('註冊請檢查電郵驗證（如有開啟）')),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('註冊失敗：${e.message}')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
    if (!SupabaseConfig.isConfigured) return;
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已登出')),
    );
    setState(() {});
  }

  Future<void> _selectOption(String key, String value) async {
    setState(() {
      _avatarState = _avatarState.copyWithOption(key, value);
    });
    await _saveAvatarState();
  }

  Future<void> _buyItem(_ShopItem item) async {
    if (_avatarState.ownedItemIds.contains(item.id)) return;
    if (_avatarState.coins < item.price) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('金幣不足，需要 ${item.price} 金幣')),
      );
      return;
    }

    await ProfileWalletService.spendCoins(item.price, reason: '購買道具：${item.name}');
    setState(() {
      _avatarState = _avatarState.purchase(item.id, item.price);
    });
    await _saveAvatarState();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已購買：${item.name}')),
    );
  }

  Future<void> _equipItem(_ShopItem item) async {
    if (!_avatarState.ownedItemIds.contains(item.id)) return;
    setState(() {
      _avatarState = _avatarState.equip(item.slot, item.id);
    });
    await _saveAvatarState();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已裝備：${item.name}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final configured = SupabaseConfig.isConfigured;
    final user = configured ? Supabase.instance.client.auth.currentUser : null;

    return Scaffold(
      appBar: AppBar(title: const Text('個人資料')),
      body: _isProfileLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (!configured)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text('尚未設定 Supabase（.env），登入功能未啟用。'),
                  ),
                if (configured && user == null) _buildAuthForm(),
                if (configured && user != null) _buildSignedIn(user),
                const SizedBox(height: 16),
                _buildAvatarPreview(),
                const SizedBox(height: 16),
                _buildCustomizationPanel(),
                const SizedBox(height: 16),
                _buildShopPanel(),
                const SizedBox(height: 16),
                _buildCoinHistoryPanel(),
              ],
            ),
    );
  }

  Widget _buildAuthForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('登入 / 註冊',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration:
                  const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration:
                  const InputDecoration(labelText: '密碼', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _isLoading ? null : _signIn,
              child: Text(_isLoading ? '登入中...' : '登入'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _isLoading ? null : _signUp,
              child: const Text('註冊'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignedIn(User user) {
    return Card(
      child: ListTile(
        title: Text('已登入：${user.email ?? user.id}'),
        trailing: FilledButton.tonal(
          onPressed: _signOut,
          child: const Text('登出'),
        ),
      ),
    );
  }

  Widget _buildAvatarPreview() {
    final equippedNames = _avatarState.equipped.values
        .map((id) => _shopItemById[id]?.name)
        .whereType<String>()
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _AvatarLayeredPreview(avatarState: _avatarState),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('我的角色', style: Theme.of(context).textTheme.titleMedium),
                      Text('金幣：${_avatarState.coins}'),
                      Text(
                        equippedNames.isEmpty
                            ? '未裝備道具'
                            : '已裝備：${equippedNames.join('、')}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomizationPanel() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('角色自訂', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            _buildChoiceRow('性別', _genderOptions, _avatarState.selectedGender),
            const SizedBox(height: 12),
            _buildChoiceRow('髮型', _hairStyleOptions, _avatarState.selectedHairStyle),
            const SizedBox(height: 12),
            _buildPresetRow(),
          ],
        ),
      ),
    );
  }

  Widget _buildChoiceRow(String label, List<String> options, String selected) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options
              .map(
                (option) => ChoiceChip(
                  label: Text(option),
                  selected: selected == option,
                  onSelected: (_) => _selectOption(
                    label == '性別' ? 'gender' : 'hair',
                    option,
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildPresetRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('角色圖樣'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _presetOptions
              .map(
                (n) => ChoiceChip(
                  label: Text('樣式$n'),
                  selected: _avatarState.selectedPreset == n,
                  onSelected: (_) async {
                    setState(() {
                      _avatarState = _avatarState.copyWith(selectedPreset: n);
                    });
                    await _saveAvatarState();
                  },
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildShopPanel() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('裝備商店', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('可購買並裝備到個人頭像：魚竿、釣箱、冰箱、衫、褲、鞋、帽、面罩'),
            const SizedBox(height: 12),
            ..._shopItems.map((item) => _buildShopItemTile(item)),
          ],
        ),
      ),
    );
  }

  Widget _buildShopItemTile(_ShopItem item) {
    final owned = _avatarState.ownedItemIds.contains(item.id);
    final equipped = _avatarState.equipped[item.slot] == item.id;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(item.name),
      subtitle: Text(
        '分類：${item.slotLabel}  •  價格：${item.price} 金幣\n稀有度：${item.rarityLabel}',
      ),
      trailing: owned
          ? FilledButton.tonal(
              onPressed: equipped ? null : () => _equipItem(item),
              child: Text(equipped ? '已裝備' : '裝備'),
            )
          : FilledButton(
              onPressed: () => _buyItem(item),
              child: const Text('購買'),
            ),
    );
  }

  Widget _buildCoinHistoryPanel() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('金幣來源明細', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (_coinHistory.isEmpty)
              const Text('暫無紀錄')
            else
              ..._coinHistory.take(12).map((item) {
                final amount = (item['amount'] as num?)?.toInt() ?? 0;
                final reason = (item['reason'] as String?) ?? '未知';
                final ts = (item['timestamp'] as String?) ?? '';
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    amount >= 0 ? Icons.add_circle : Icons.remove_circle,
                    color: amount >= 0 ? Colors.green : Colors.red,
                  ),
                  title: Text(reason),
                  subtitle: Text(ts.replaceFirst('T', ' ').split('.').first),
                  trailing: Text(
                    amount >= 0 ? '+$amount' : '$amount',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: amount >= 0 ? Colors.green : Colors.red,
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _AvatarLayeredPreview extends StatelessWidget {
  const _AvatarLayeredPreview({required this.avatarState});

  final _AvatarProfileState avatarState;

  @override
  Widget build(BuildContext context) {
    final preset = avatarState.selectedPreset.clamp(1, 5);
    final bodyAsset = avatarState.selectedGender == 'female'
        ? 'assets/avatar/layers/body_female_0$preset.svg'
        : 'assets/avatar/layers/body_male_0$preset.svg';

    final hairAsset = switch (avatarState.selectedHairStyle) {
      'long' => 'assets/avatar/layers/hair_long.svg',
      'curly' => 'assets/avatar/layers/hair_curly.svg',
      'buzz' => 'assets/avatar/layers/hair_buzz.svg',
      'ponytail' => 'assets/avatar/layers/hair_ponytail.svg',
      _ => 'assets/avatar/layers/hair_short.svg',
    };

    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _svg(bodyAsset),
          _svg(hairAsset),
          if (avatarState.equipped['shirt'] != null)
            _svg(_assetForItemId(avatarState.equipped['shirt']!)),
          if (avatarState.equipped['pants'] != null)
            _svg(_assetForItemId(avatarState.equipped['pants']!)),
          if (avatarState.equipped['shoes'] != null)
            _svg(_assetForItemId(avatarState.equipped['shoes']!)),
          if (avatarState.equipped['hat'] != null)
            _svg(_assetForItemId(avatarState.equipped['hat']!)),
          if (avatarState.equipped['mask'] != null)
            _svg(_assetForItemId(avatarState.equipped['mask']!)),
          if (avatarState.equipped['rod'] != null)
            _svg(_assetForItemId(avatarState.equipped['rod']!)),
          if (avatarState.equipped['tackle_box'] != null)
            _svg(_assetForItemId(avatarState.equipped['tackle_box']!)),
          if (avatarState.equipped['cooler'] != null)
            _svg(_assetForItemId(avatarState.equipped['cooler']!)),
        ],
      ),
    );
  }

  Widget _svg(String path) {
    return SvgPicture.asset(
      path,
      fit: BoxFit.contain,
      placeholderBuilder: (_) => const SizedBox.shrink(),
    );
  }
}

String _assetForItemId(String itemId) => 'assets/avatar/layers/$itemId.svg';

const _genderOptions = ['male', 'female'];
const _hairStyleOptions = ['short', 'long', 'curly', 'buzz', 'ponytail'];
const _presetOptions = [1, 2, 3, 4, 5];

class _AvatarProfileState {
  const _AvatarProfileState({
    required this.selectedGender,
    required this.selectedHairStyle,
    required this.selectedPreset,
    required this.coins,
    required this.ownedItemIds,
    required this.equipped,
  });

  factory _AvatarProfileState.initial() => const _AvatarProfileState(
        selectedGender: 'male',
        selectedHairStyle: 'short',
        selectedPreset: 1,
        coins: 500,
        ownedItemIds: {
          'shirt_01',
          'pants_01',
          'shoes_01',
          'hat_01',
          'mask_01',
          'rod_01',
          'tackle_box_01',
          'cooler_01',
        },
        equipped: {
          'shirt': 'shirt_01',
          'pants': 'pants_01',
          'shoes': 'shoes_01',
          'hat': 'hat_01',
          'mask': 'mask_01',
          'rod': 'rod_01',
          'tackle_box': 'tackle_box_01',
          'cooler': 'cooler_01',
        },
      );

  factory _AvatarProfileState.fromMap(Map<String, dynamic> map) => _AvatarProfileState(
        selectedGender: (() {
          final g = (map['selectedGender'] as String?) ?? 'male';
          return _genderOptions.contains(g) ? g : 'male';
        })(),
        selectedHairStyle: (map['selectedHairStyle'] as String?) ?? 'short',
        selectedPreset: ((map['selectedPreset'] as num?)?.toInt() ?? 1).clamp(1, 5),
        coins: (map['coins'] as num?)?.toInt() ?? 500,
        ownedItemIds: Set<String>.from((map['ownedItemIds'] as List?) ?? const []),
        equipped: Map<String, String>.from((map['equipped'] as Map?) ?? const {}),
      );

  final String selectedGender;
  final String selectedHairStyle;
  final int selectedPreset;
  final int coins;
  final Set<String> ownedItemIds;
  final Map<String, String> equipped;

  _AvatarProfileState copyWith({
    String? selectedGender,
    String? selectedHairStyle,
    int? selectedPreset,
    int? coins,
    Set<String>? ownedItemIds,
    Map<String, String>? equipped,
  }) =>
      _AvatarProfileState(
        selectedGender: selectedGender ?? this.selectedGender,
        selectedHairStyle: selectedHairStyle ?? this.selectedHairStyle,
        selectedPreset: selectedPreset ?? this.selectedPreset,
        coins: coins ?? this.coins,
        ownedItemIds: ownedItemIds ?? this.ownedItemIds,
        equipped: equipped ?? this.equipped,
      );

  _AvatarProfileState copyWithOption(String key, String value) {
    if (key == 'gender') return copyWith(selectedGender: value);
    if (key == 'hair') return copyWith(selectedHairStyle: value);
    return this;
  }

  _AvatarProfileState purchase(String itemId, int price) {
    final nextOwned = Set<String>.from(ownedItemIds)..add(itemId);
    return copyWith(coins: coins - price, ownedItemIds: nextOwned);
  }

  _AvatarProfileState equip(String slot, String itemId) {
    final nextEquipped = Map<String, String>.from(equipped)..[slot] = itemId;
    return copyWith(equipped: nextEquipped);
  }

  Map<String, dynamic> toMap() => {
        'selectedGender': selectedGender,
        'selectedHairStyle': selectedHairStyle,
        'selectedPreset': selectedPreset,
        'coins': coins,
        'ownedItemIds': ownedItemIds.toList(),
        'equipped': equipped,
      };
}

class _ShopItem {
  const _ShopItem({
    required this.id,
    required this.name,
    required this.price,
    required this.slot,
    required this.slotLabel,
    required this.rarityLabel,
  });

  final String id;
  final String name;
  final int price;
  final String slot;
  final String slotLabel;
  final String rarityLabel;
}

const _shopItems = <_ShopItem>[
  _ShopItem(id: 'hat_01', name: '帽 初級-1', price: 120, slot: 'hat', slotLabel: '帽', rarityLabel: '初級'),
  _ShopItem(id: 'hat_02', name: '帽 初級-2', price: 180, slot: 'hat', slotLabel: '帽', rarityLabel: '初級'),
  _ShopItem(id: 'hat_03', name: '帽 中級-1', price: 320, slot: 'hat', slotLabel: '帽', rarityLabel: '中級'),
  _ShopItem(id: 'hat_04', name: '帽 中級-2', price: 450, slot: 'hat', slotLabel: '帽', rarityLabel: '中級'),
  _ShopItem(id: 'hat_05', name: '帽 高級-1', price: 800, slot: 'hat', slotLabel: '帽', rarityLabel: '高級'),
  _ShopItem(id: 'hat_06', name: '帽 高級-2', price: 1200, slot: 'hat', slotLabel: '帽', rarityLabel: '高級'),
  _ShopItem(id: 'mask_01', name: '面罩 初級-1', price: 120, slot: 'mask', slotLabel: '面罩', rarityLabel: '初級'),
  _ShopItem(id: 'mask_02', name: '面罩 初級-2', price: 180, slot: 'mask', slotLabel: '面罩', rarityLabel: '初級'),
  _ShopItem(id: 'mask_03', name: '面罩 中級-1', price: 320, slot: 'mask', slotLabel: '面罩', rarityLabel: '中級'),
  _ShopItem(id: 'mask_04', name: '面罩 中級-2', price: 450, slot: 'mask', slotLabel: '面罩', rarityLabel: '中級'),
  _ShopItem(id: 'mask_05', name: '面罩 高級-1', price: 800, slot: 'mask', slotLabel: '面罩', rarityLabel: '高級'),
  _ShopItem(id: 'mask_06', name: '面罩 高級-2', price: 1200, slot: 'mask', slotLabel: '面罩', rarityLabel: '高級'),
  _ShopItem(id: 'shirt_01', name: '衫 初級-1', price: 120, slot: 'shirt', slotLabel: '衫', rarityLabel: '初級'),
  _ShopItem(id: 'shirt_02', name: '衫 初級-2', price: 180, slot: 'shirt', slotLabel: '衫', rarityLabel: '初級'),
  _ShopItem(id: 'shirt_03', name: '衫 中級-1', price: 320, slot: 'shirt', slotLabel: '衫', rarityLabel: '中級'),
  _ShopItem(id: 'shirt_04', name: '衫 中級-2', price: 450, slot: 'shirt', slotLabel: '衫', rarityLabel: '中級'),
  _ShopItem(id: 'shirt_05', name: '衫 高級-1', price: 800, slot: 'shirt', slotLabel: '衫', rarityLabel: '高級'),
  _ShopItem(id: 'shirt_06', name: '衫 高級-2', price: 1200, slot: 'shirt', slotLabel: '衫', rarityLabel: '高級'),
  _ShopItem(id: 'pants_01', name: '褲 初級-1', price: 120, slot: 'pants', slotLabel: '褲', rarityLabel: '初級'),
  _ShopItem(id: 'pants_02', name: '褲 初級-2', price: 180, slot: 'pants', slotLabel: '褲', rarityLabel: '初級'),
  _ShopItem(id: 'pants_03', name: '褲 中級-1', price: 320, slot: 'pants', slotLabel: '褲', rarityLabel: '中級'),
  _ShopItem(id: 'pants_04', name: '褲 中級-2', price: 450, slot: 'pants', slotLabel: '褲', rarityLabel: '中級'),
  _ShopItem(id: 'pants_05', name: '褲 高級-1', price: 800, slot: 'pants', slotLabel: '褲', rarityLabel: '高級'),
  _ShopItem(id: 'pants_06', name: '褲 高級-2', price: 1200, slot: 'pants', slotLabel: '褲', rarityLabel: '高級'),
  _ShopItem(id: 'shoes_01', name: '鞋 初級-1', price: 120, slot: 'shoes', slotLabel: '鞋', rarityLabel: '初級'),
  _ShopItem(id: 'shoes_02', name: '鞋 初級-2', price: 180, slot: 'shoes', slotLabel: '鞋', rarityLabel: '初級'),
  _ShopItem(id: 'shoes_03', name: '鞋 中級-1', price: 320, slot: 'shoes', slotLabel: '鞋', rarityLabel: '中級'),
  _ShopItem(id: 'shoes_04', name: '鞋 中級-2', price: 450, slot: 'shoes', slotLabel: '鞋', rarityLabel: '中級'),
  _ShopItem(id: 'shoes_05', name: '鞋 高級-1', price: 800, slot: 'shoes', slotLabel: '鞋', rarityLabel: '高級'),
  _ShopItem(id: 'shoes_06', name: '鞋 高級-2', price: 1200, slot: 'shoes', slotLabel: '鞋', rarityLabel: '高級'),
  _ShopItem(id: 'rod_01', name: '魚竿 初級-1', price: 120, slot: 'rod', slotLabel: '魚竿', rarityLabel: '初級'),
  _ShopItem(id: 'rod_02', name: '魚竿 初級-2', price: 180, slot: 'rod', slotLabel: '魚竿', rarityLabel: '初級'),
  _ShopItem(id: 'rod_03', name: '魚竿 中級-1', price: 320, slot: 'rod', slotLabel: '魚竿', rarityLabel: '中級'),
  _ShopItem(id: 'rod_04', name: '魚竿 中級-2', price: 450, slot: 'rod', slotLabel: '魚竿', rarityLabel: '中級'),
  _ShopItem(id: 'rod_05', name: '魚竿 高級-1', price: 800, slot: 'rod', slotLabel: '魚竿', rarityLabel: '高級'),
  _ShopItem(id: 'rod_06', name: '魚竿 高級-2', price: 1200, slot: 'rod', slotLabel: '魚竿', rarityLabel: '高級'),
  _ShopItem(id: 'tackle_box_01', name: '釣箱 初級-1', price: 120, slot: 'tackle_box', slotLabel: '釣箱', rarityLabel: '初級'),
  _ShopItem(id: 'tackle_box_02', name: '釣箱 初級-2', price: 180, slot: 'tackle_box', slotLabel: '釣箱', rarityLabel: '初級'),
  _ShopItem(id: 'tackle_box_03', name: '釣箱 中級-1', price: 320, slot: 'tackle_box', slotLabel: '釣箱', rarityLabel: '中級'),
  _ShopItem(id: 'tackle_box_04', name: '釣箱 中級-2', price: 450, slot: 'tackle_box', slotLabel: '釣箱', rarityLabel: '中級'),
  _ShopItem(id: 'tackle_box_05', name: '釣箱 高級-1', price: 800, slot: 'tackle_box', slotLabel: '釣箱', rarityLabel: '高級'),
  _ShopItem(id: 'tackle_box_06', name: '釣箱 高級-2', price: 1200, slot: 'tackle_box', slotLabel: '釣箱', rarityLabel: '高級'),
  _ShopItem(id: 'cooler_01', name: '冰箱 初級-1', price: 120, slot: 'cooler', slotLabel: '冰箱', rarityLabel: '初級'),
  _ShopItem(id: 'cooler_02', name: '冰箱 初級-2', price: 180, slot: 'cooler', slotLabel: '冰箱', rarityLabel: '初級'),
  _ShopItem(id: 'cooler_03', name: '冰箱 中級-1', price: 320, slot: 'cooler', slotLabel: '冰箱', rarityLabel: '中級'),
  _ShopItem(id: 'cooler_04', name: '冰箱 中級-2', price: 450, slot: 'cooler', slotLabel: '冰箱', rarityLabel: '中級'),
  _ShopItem(id: 'cooler_05', name: '冰箱 高級-1', price: 800, slot: 'cooler', slotLabel: '冰箱', rarityLabel: '高級'),
  _ShopItem(id: 'cooler_06', name: '冰箱 高級-2', price: 1200, slot: 'cooler', slotLabel: '冰箱', rarityLabel: '高級'),
];

final _shopItemById = {for (final item in _shopItems) item.id: item};
