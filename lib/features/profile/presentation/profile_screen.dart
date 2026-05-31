import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';

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
    if (!mounted) return;

    if (saved is Map) {
      setState(() {
        _avatarState = _AvatarProfileState.fromMap(Map<String, dynamic>.from(saved));
        _isProfileLoading = false;
      });
      return;
    }

    setState(() => _isProfileLoading = false);
  }

  Future<void> _saveAvatarState() async {
    final box = await Hive.openBox(_profileBoxName);
    await box.put('avatar_state', _avatarState.toMap());
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
      subtitle: Text('分類：${item.slotLabel}  •  價格：${item.price} 金幣'),
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
}

class _AvatarLayeredPreview extends StatelessWidget {
  const _AvatarLayeredPreview({required this.avatarState});

  final _AvatarProfileState avatarState;

  @override
  Widget build(BuildContext context) {
    final genderSymbol = avatarState.selectedGender == 'male'
        ? '♂'
        : avatarState.selectedGender == 'female'
            ? '♀'
            : '⚥';

    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.blueGrey.shade50,
        border: Border.all(color: Colors.blueGrey.shade200),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Positioned(
            bottom: 22,
            child: Icon(Icons.person, size: 50, color: Colors.blueGrey),
          ),
          Positioned(
            top: 12,
            child: Icon(
              _hairIcon(avatarState.selectedHairStyle),
              size: 22,
              color: Colors.brown.shade700,
            ),
          ),
          if (avatarState.equipped['hat'] != null)
            const Positioned(top: 2, child: Icon(Icons.checkroom, size: 18, color: Colors.deepOrange)),
          if (avatarState.equipped['mask'] != null)
            const Positioned(top: 37, child: Icon(Icons.masks, size: 18, color: Colors.teal)),
          if (avatarState.equipped['shirt'] != null)
            const Positioned(bottom: 26, child: Icon(Icons.dry_cleaning, size: 18, color: Colors.indigo)),
          if (avatarState.equipped['pants'] != null)
            const Positioned(bottom: 12, child: Icon(Icons.accessibility_new, size: 16, color: Colors.brown)),
          if (avatarState.equipped['shoes'] != null)
            const Positioned(bottom: 2, child: Icon(Icons.hiking, size: 16, color: Colors.black54)),
          if (avatarState.equipped['rod'] != null)
            const Positioned(right: 4, top: 46, child: Icon(Icons.phishing, size: 17, color: Colors.blue)),
          if (avatarState.equipped['tackle_box'] != null)
            const Positioned(left: 3, bottom: 20, child: Icon(Icons.inventory_2, size: 16, color: Colors.amber)),
          if (avatarState.equipped['cooler'] != null)
            const Positioned(left: 2, bottom: 5, child: Icon(Icons.kitchen, size: 16, color: Colors.lightBlue)),
          Positioned(
            right: 4,
            top: 4,
            child: Text(
              genderSymbol,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  static IconData _hairIcon(String hair) {
    switch (hair) {
      case 'long':
        return Icons.face_retouching_natural;
      case 'curly':
        return Icons.bubble_chart;
      case 'buzz':
        return Icons.crop;
      case 'ponytail':
        return Icons.brush;
      default:
        return Icons.face;
    }
  }
}

const _genderOptions = ['male', 'female', 'other'];
const _hairStyleOptions = ['short', 'long', 'curly', 'buzz', 'ponytail'];

class _AvatarProfileState {
  const _AvatarProfileState({
    required this.selectedGender,
    required this.selectedHairStyle,
    required this.coins,
    required this.ownedItemIds,
    required this.equipped,
  });

  factory _AvatarProfileState.initial() => const _AvatarProfileState(
        selectedGender: 'other',
        selectedHairStyle: 'short',
        coins: 500,
        ownedItemIds: {'shirt_basic', 'pants_basic', 'shoes_basic'},
        equipped: {
          'shirt': 'shirt_basic',
          'pants': 'pants_basic',
          'shoes': 'shoes_basic',
        },
      );

  factory _AvatarProfileState.fromMap(Map<String, dynamic> map) => _AvatarProfileState(
        selectedGender: (map['selectedGender'] as String?) ?? 'other',
        selectedHairStyle: (map['selectedHairStyle'] as String?) ?? 'short',
        coins: (map['coins'] as num?)?.toInt() ?? 500,
        ownedItemIds: Set<String>.from((map['ownedItemIds'] as List?) ?? const []),
        equipped: Map<String, String>.from((map['equipped'] as Map?) ?? const {}),
      );

  final String selectedGender;
  final String selectedHairStyle;
  final int coins;
  final Set<String> ownedItemIds;
  final Map<String, String> equipped;

  _AvatarProfileState copyWith({
    String? selectedGender,
    String? selectedHairStyle,
    int? coins,
    Set<String>? ownedItemIds,
    Map<String, String>? equipped,
  }) =>
      _AvatarProfileState(
        selectedGender: selectedGender ?? this.selectedGender,
        selectedHairStyle: selectedHairStyle ?? this.selectedHairStyle,
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
  });

  final String id;
  final String name;
  final int price;
  final String slot;
  final String slotLabel;
}

const _shopItems = <_ShopItem>[
  _ShopItem(id: 'rod_pro', name: '碳纖魚竿', price: 120, slot: 'rod', slotLabel: '魚竿'),
  _ShopItem(id: 'tackle_advanced', name: '專業釣箱', price: 100, slot: 'tackle_box', slotLabel: '釣箱'),
  _ShopItem(id: 'cooler_arctic', name: '保冷冰箱', price: 90, slot: 'cooler', slotLabel: '冰箱'),
  _ShopItem(id: 'shirt_basic', name: '基本釣魚衫', price: 0, slot: 'shirt', slotLabel: '衫'),
  _ShopItem(id: 'shirt_dryfit', name: '速乾防曬衫', price: 80, slot: 'shirt', slotLabel: '衫'),
  _ShopItem(id: 'pants_basic', name: '基本長褲', price: 0, slot: 'pants', slotLabel: '褲'),
  _ShopItem(id: 'pants_cargo', name: '多袋工裝褲', price: 75, slot: 'pants', slotLabel: '褲'),
  _ShopItem(id: 'shoes_basic', name: '基本防滑鞋', price: 0, slot: 'shoes', slotLabel: '鞋'),
  _ShopItem(id: 'shoes_grip', name: '防滑釘鞋', price: 70, slot: 'shoes', slotLabel: '鞋'),
  _ShopItem(id: 'hat_bucket', name: '漁夫帽', price: 55, slot: 'hat', slotLabel: '帽'),
  _ShopItem(id: 'hat_cap', name: '防曬鴨舌帽', price: 60, slot: 'hat', slotLabel: '帽'),
  _ShopItem(id: 'mask_uv', name: '防曬面罩', price: 45, slot: 'mask', slotLabel: '面罩'),
];

final _shopItemById = {for (final item in _shopItems) item.id: item};
