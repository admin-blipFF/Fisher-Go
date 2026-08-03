import 'dart:async';

import 'package:flutter/material.dart';

import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/auth/local_account_service.dart';
import '../../../core/admin/admin_ops_service.dart';
import '../../../core/config/auth_redirect_config.dart';
import '../../../core/config/public_app_config.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/notifications/notification_opt_in.dart';
import '../../../core/notifications/notification_permission_service.dart';
import '../../../core/notifications/notification_token_registration_service.dart';
import '../data/player_progress_service.dart';
import '../data/profile_wallet_service.dart';
import '../domain/game_shop_item.dart';
import 'daily_task_semantics.dart';
import 'profile_semantics.dart';
import '../../../domain/boat_vendor.dart';
import '../../../features/shop/presentation/boat_vendor_shop_card.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.onBoatRented});

  final VoidCallback? onBoatRented;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with WidgetsBindingObserver {
  static const _profileBoxName = 'profile_customization';

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _notificationStore = NotificationPreferenceStore();
  final _notificationPermission = NotificationPermissionService();
  final _notificationTokenRegistration = NotificationTokenRegistrationService();

  bool _isLoading = false;
  bool _isProfileLoading = true;

  late AvatarProfileViewState _avatarState;
  PlayerProgressState _progressState = PlayerProgressState.empty;
  List<Map<String, dynamic>> _coinHistory = const [];
  Map<String, int> _gameConsumables = const {};
  String _selectedEquipmentSlot = 'rod';
  NotificationPreference _notificationPreference =
      const NotificationPreference.undecided();
  NotificationPermissionStatus _notificationPermissionStatus =
      NotificationPermissionStatus.unavailable;
  bool _notificationLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _avatarState = AvatarProfileViewState.initial();
    _loadAvatarState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshNotificationState());
    }
  }

  Future<void> _loadAvatarState() async {
    await LocalAccountService.restoreSession();
    final claimedAmount = await AdminOpsService.claimPendingCoinGrants();
    final box =
        await Hive.openBox(LocalAccountService.boxNameFor(_profileBoxName));
    final saved = box.get('avatar_state');
    final history = await ProfileWalletService.getCoinHistory();
    final consumables = await ProfileWalletService.getConsumables();
    final progress = await PlayerProgressService.loadState();
    final notificationPreference = await _notificationStore.load();
    final notificationStatus = await _notificationPermission.status();
    if (!mounted) return;

    if (claimedAmount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已領取 Admin 派發金幣 +$claimedAmount')),
      );
    }

    if (saved is Map) {
      setState(() {
        _avatarState =
            AvatarProfileViewState.fromMap(Map<String, dynamic>.from(saved));
        _coinHistory = history;
        _gameConsumables = consumables;
        _progressState = progress;
        _notificationPreference = notificationPreference;
        _notificationPermissionStatus = notificationStatus;
        _isProfileLoading = false;
      });
      return;
    }

    setState(() {
      _coinHistory = history;
      _gameConsumables = consumables;
      _progressState = progress;
      _notificationPreference = notificationPreference;
      _notificationPermissionStatus = notificationStatus;
      _isProfileLoading = false;
    });
  }

  Future<void> _refreshNotificationState() async {
    final preference = await _notificationStore.load();
    final status = await _notificationPermission.status();
    if (!mounted) return;
    setState(() {
      _notificationPreference = preference;
      _notificationPermissionStatus = status;
    });
  }

  Future<void> _saveAvatarState() async {
    final box =
        await Hive.openBox(LocalAccountService.boxNameFor(_profileBoxName));
    final existingRaw = box.get('avatar_state');
    final existing = existingRaw is Map
        ? Map<String, dynamic>.from(existingRaw)
        : <String, dynamic>{};
    final merged = _avatarState.toMap()
      ..addAll({
        if (existing['coinHistory'] != null)
          'coinHistory': existing['coinHistory'],
        if (existing['consumables'] != null)
          'consumables': existing['consumables'],
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
      await LocalAccountService.restoreSession();
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
      final auth = Supabase.instance.client.auth;
      final currentUser = auth.currentUser;
      final isAnonymous = currentUser?.isAnonymous ?? false;

      if (isAnonymous) {
        // Upgrade the anonymous account in place so all catches and progress
        // are preserved under the same user_id. A confirmation email is sent;
        // once verified, the email/password becomes a permanent login.
        await auth.updateUser(
          UserAttributes(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          ),
          emailRedirectTo: AuthRedirectConfig.oauthRedirect,
        );
        await LocalAccountService.restoreSession();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('請檢查電郵完成驗證。你目前的魚獲與進度會保留。'),
          ),
        );
      } else {
        final response = await auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          emailRedirectTo: AuthRedirectConfig.oauthRedirect,
        );
        final newUserId = response.user?.id;
        if (newUserId != null) {
          await LocalAccountService.migrateGuestDataToAccount(newUserId);
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('請檢查電郵，按連結完成 FisherGO 帳戶驗證。')),
        );
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('註冊失敗：${e.message}')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    if (!SupabaseConfig.isConfigured) return;
    setState(() => _isLoading = true);
    try {
      final auth = Supabase.instance.client.auth;
      final session = auth.currentSession;
      if (session != null) {
        final launched = await auth.linkIdentity(
          OAuthProvider.google,
          redirectTo: AuthRedirectConfig.oauthRedirect,
        );
        if (!launched) {
          throw StateError('無法開啟 Google 登入頁面');
        }
        return;
      }

      await auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: AuthRedirectConfig.oauthRedirect,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google 登入失敗：${e.message}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google 登入失敗：$e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
    if (!SupabaseConfig.isConfigured) return;
    await Supabase.instance.client.auth.signOut();
    await LocalAccountService.signOut();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已登出')),
    );
    setState(() {});
  }

  Future<void> _deleteAccount() async {
    if (!PublicAppConfig.accountDeletionEnabled ||
        !SupabaseConfig.isConfigured) {
      return;
    }
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || user.isAnonymous) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('刪除帳戶？'),
        content: const Text(
          '這會永久刪除雲端魚獲、相片和帳戶資料，不能復原。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('確認刪除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'delete-account',
      );
      final deleted =
          response.data is Map && (response.data as Map)['deleted'] == true;
      if (!deleted) {
        throw StateError('帳戶刪除服務沒有確認完成');
      }

      await LocalAccountService.clearCurrentAccountData();
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (_) {
        // The Auth user has already been removed server-side.
      }
      await LocalAccountService.signOut();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('帳戶及雲端資料已刪除')),
      );
      setState(() {});
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('刪除帳戶未完成，請聯絡支援：$error')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectOption(
    String key,
    String value, {
    StateSetter? routeSetState,
  }) async {
    setState(() {
      _avatarState = _avatarState.copyWithOption(key, value);
    });
    routeSetState?.call(() {});
    await _saveAvatarState();
  }

  Future<void> _buyItem(_ShopItem item, {StateSetter? routeSetState}) async {
    if (_avatarState.ownedItemIds.contains(item.id)) return;
    if (_avatarState.coins < item.price) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('金幣不足，需要 ${item.price} 金幣')),
      );
      return;
    }

    await ProfileWalletService.spendCoins(item.price,
        reason: '購買道具：${item.name}');
    setState(() {
      _avatarState = _avatarState.purchase(item.id, item.price);
    });
    routeSetState?.call(() {});
    await _saveAvatarState();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已購買：${item.name}')),
    );
  }

  Future<void> _equipItem(_ShopItem item, {StateSetter? routeSetState}) async {
    if (!_avatarState.ownedItemIds.contains(item.id)) return;
    setState(() {
      _avatarState = _avatarState.equip(item.slot, item.id);
    });
    routeSetState?.call(() {});
    await _saveAvatarState();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已裝備：${item.name}')),
    );
  }

  Future<void> _buyGameItem(GameShopItem item,
      {StateSetter? routeSetState}) async {
    final ok = await ProfileWalletService.buyConsumable(item);
    if (!ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('金幣不足，需要 ${item.price} 金幣')),
      );
      return;
    }

    final box =
        await Hive.openBox(LocalAccountService.boxNameFor(_profileBoxName));
    final saved = box.get('avatar_state');
    final history = await ProfileWalletService.getCoinHistory();
    final consumables = await ProfileWalletService.getConsumables();
    if (!mounted) return;
    setState(() {
      if (saved is Map) {
        _avatarState =
            AvatarProfileViewState.fromMap(Map<String, dynamic>.from(saved));
      }
      _coinHistory = history;
      _gameConsumables = consumables;
    });
    routeSetState?.call(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已購買：${item.name}')),
    );
  }

  Future<void> _claimDailyTaskReward(PlayerDailyTaskSummary task) async {
    final result = await PlayerProgressService.claimDailyTaskReward(task.id);
    if (!mounted) return;

    if (!result.claimed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(task.isClaimed ? '今日已領取：${task.title}' : '任務尚未完成'),
        ),
      );
      setState(() => _progressState = result.state);
      return;
    }

    final updatedCoins = await ProfileWalletService.addCoins(
      result.rewardCoins,
      reason: '每日任務獎勵：${task.title}',
      rewardKind: 'daily_task_${task.id}',
      claimKey:
          'daily-task:${task.id}:${DateTime.now().toUtc().toIso8601String().substring(0, 10)}',
    );
    final history = await ProfileWalletService.getCoinHistory();
    final box =
        await Hive.openBox(LocalAccountService.boxNameFor(_profileBoxName));
    final saved = box.get('avatar_state');
    if (!mounted) return;
    setState(() {
      _progressState = result.state;
      _coinHistory = history;
      if (saved is Map) {
        _avatarState =
            AvatarProfileViewState.fromMap(Map<String, dynamic>.from(saved));
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            '已領取 ${task.title} +${result.rewardCoins} 金幣（現有 $updatedCoins）'),
      ),
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
                    child: Text('雲端備份暫未啟用；你仍可用本機試玩和記錄魚獲。'),
                  ),
                if (configured && user == null) _buildAuthForm(),
                if (configured && user != null) _buildSignedIn(user),
                if (_hasLegalSupportLinks) ...[
                  const SizedBox(height: 16),
                  _buildLegalSupportPanel(),
                ],
                const SizedBox(height: 16),
                _buildProgressPanel(),
                if (_shouldShowNotificationOptIn) ...[
                  const SizedBox(height: 16),
                  _buildNotificationOptInPanel(),
                ] else if (_shouldShowNotificationSettings) ...[
                  const SizedBox(height: 16),
                  _buildNotificationSettingsPanel(),
                ],
                const SizedBox(height: 16),
                _buildAvatarPreview(),
                const SizedBox(height: 16),
                _buildProfileActionPanel(),
                const SizedBox(height: 16),
                _buildCoinHistoryPanel(),
                const Divider(height: 32),
                const Text('船家服務',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                for (final vendor in kBoatVendors)
                  BoatVendorShopCard(
                    vendor: vendor,
                    onRented: widget.onBoatRented,
                  ),
              ],
            ),
    );
  }

  bool get _hasLegalSupportLinks =>
      _privacyPolicyUri != null ||
      PublicAppConfig.supportEmail.trim().isNotEmpty;

  Uri? get _privacyPolicyUri {
    final uri = Uri.tryParse(PublicAppConfig.privacyPolicyUrl.trim());
    if (uri == null || uri.host.isEmpty) return null;
    if (uri.scheme != 'https' && uri.scheme != 'http') return null;
    return uri;
  }

  Widget _buildLegalSupportPanel() {
    final privacyUri = _privacyPolicyUri;
    final supportEmail = PublicAppConfig.supportEmail.trim();
    final reportUri = PublicAppConfig.problemReportUri;

    return Card(
      child: Column(
        children: [
          if (privacyUri != null)
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('私隱政策'),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => _openExternalLink(privacyUri),
            ),
          if (supportEmail.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.support_agent),
              title: const Text('聯絡支援'),
              subtitle: Text(supportEmail),
              trailing: const Icon(Icons.mail_outline),
              onTap: () => _openExternalLink(
                Uri(scheme: 'mailto', path: supportEmail),
              ),
            ),
          if (reportUri != null)
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('報告問題'),
              subtitle: const Text('把問題位置和描述寄給支援團隊'),
              trailing: const Icon(Icons.mail_outline),
              onTap: () => _openExternalLink(reportUri),
            ),
        ],
      ),
    );
  }

  Future<void> _openExternalLink(Uri uri) async {
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('暫時未能開啟連結')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('暫時未能開啟連結')),
      );
    }
  }

  Widget _buildAuthForm({bool isUpgrade = false}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isUpgrade ? '建立帳戶保存進度' : 'FisherGO 帳戶',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isUpgrade
                  ? '你目前使用訪客雲端帳戶；用 Email 或 Google 建立帳戶即可保留現有進度。'
                  : '可先以訪客模式試玩；建立帳戶後可備份魚獲、換機保留紀錄，之後參加排行榜。',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 4),
            Text('v0.1.1 — Google 登入測試中',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                  labelText: 'Email', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                  labelText: '密碼', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _isLoading ? null : _signIn,
              child: Text(_isLoading ? '登入中...' : '登入 FisherGO'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _isLoading ? null : _signUp,
              child: const Text('建立 FisherGO 帳戶'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _signInWithGoogle,
              icon: const Icon(Icons.g_mobiledata, size: 28),
              label: const Text('使用 Google 登入'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignedIn(User user) {
    if (user.isAnonymous) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: ListTile(
              title: const Text('訪客雲端帳戶'),
              subtitle: const Text('目前進度已同步；建立正式帳戶即可換機保留。'),
              trailing: TextButton(
                onPressed: _signOut,
                child: const Text('退出訪客'),
              ),
            ),
          ),
          _buildAuthForm(isUpgrade: true),
        ],
      );
    }

    return Card(
      child: Column(
        children: [
          ListTile(
            title: Text('FisherGO 帳戶：${user.email ?? user.id}'),
            subtitle: const Text('魚獲可備份到雲端，之後可換機保留紀錄。'),
            trailing: FilledButton.tonal(
              onPressed: _signOut,
              child: const Text('登出'),
            ),
          ),
          if (PublicAppConfig.accountDeletionEnabled)
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _deleteAccount,
                  icon: const Icon(Icons.delete_forever_outlined),
                  label: const Text('刪除帳戶'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProgressPanel() {
    final theme = Theme.of(context);
    final tasks = PlayerProgressService.dailyTasksFor(_progressState);
    final xpProgress =
        (_progressState.xp / _progressState.xpForNextLevel).clamp(0.0, 1.0);
    final completedCount = tasks.where((task) => task.isCompleted).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.primaryContainer,
                    border: Border.all(color: theme.colorScheme.primary),
                  ),
                  child: Text(
                    'Lv.${_progressState.level}',
                    style: TextStyle(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '釣手進度',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: xpProgress,
                          minHeight: 9,
                          backgroundColor: theme
                              .colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.9),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${_progressState.xp}/${_progressState.xpForNextLevel} XP',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildProgressChip(
                  icon: Icons.local_fire_department,
                  label: '連續 ${_progressState.currentStreakDays} 日',
                  color: Colors.deepOrange,
                ),
                _buildProgressChip(
                  icon: Icons.emoji_events,
                  label: '最佳 ${_progressState.bestStreakDays} 日',
                  color: Colors.amber.shade800,
                ),
                _buildProgressChip(
                  icon: Icons.task_alt,
                  label: '今日 $completedCount/${tasks.length}',
                  color: Colors.teal,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              '今日任務',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            for (final task in tasks) _buildDailyTaskRow(task),
          ],
        ),
      ),
    );
  }

  bool get _shouldShowNotificationOptIn =>
      _notificationPermissionStatus !=
          NotificationPermissionStatus.unavailable &&
      NotificationOptInPolicy.shouldPrompt(
        totalCatches: _progressState.totalCatches,
        preference: _notificationPreference,
        now: DateTime.now(),
      );

  bool get _shouldShowNotificationSettings =>
      _notificationPermissionStatus == NotificationPermissionStatus.denied &&
      _notificationPreference.choice != NotificationOptInChoice.undecided;

  Widget _buildNotificationOptInPanel() {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.notifications_active_outlined,
                    color: theme.colorScheme.onSecondaryContainer),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '釣點及活動提醒',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '完成首個釣獲後，你可以開啟通知，收到附近釣點及活動更新。',
              style: TextStyle(color: theme.colorScheme.onSecondaryContainer),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed:
                      _notificationLoading ? null : _deferNotificationOptIn,
                  child: const Text('稍後'),
                ),
                FilledButton.icon(
                  onPressed: _notificationLoading ? null : _enableNotifications,
                  icon: _notificationLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.notifications_active_outlined),
                  label: const Text('開啟通知'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationSettingsPanel() {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.notifications_off_outlined,
              color: theme.colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '通知未開啟',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '你可以在系統設定重新開啟釣點及活動提醒。',
                    style: TextStyle(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.tonalIcon(
                      onPressed: _openNotificationSettings,
                      icon: const Icon(Icons.settings_outlined),
                      label: const Text('前往系統設定'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deferNotificationOptIn() async {
    final now = DateTime.now();
    await _notificationStore.defer(now);
    if (!mounted) return;
    setState(
        () => _notificationPreference = NotificationPreference.deferredAt(now));
  }

  Future<void> _enableNotifications() async {
    setState(() => _notificationLoading = true);
    final status = await _notificationPermission.request();
    if (status == NotificationPermissionStatus.granted) {
      final token = await _notificationPermission.deviceToken();
      unawaited(_notificationTokenRegistration.register(token));
      await _notificationStore.setEnabled();
    } else if (status == NotificationPermissionStatus.denied) {
      await _notificationStore.setDeclined();
    }
    if (!mounted) return;

    setState(() {
      _notificationPermissionStatus = status;
      _notificationPreference = switch (status) {
        NotificationPermissionStatus.granted =>
          const NotificationPreference.enabled(),
        NotificationPermissionStatus.denied =>
          const NotificationPreference.declined(),
        NotificationPermissionStatus.unavailable => _notificationPreference,
      };
      _notificationLoading = false;
    });

    final message = switch (status) {
      NotificationPermissionStatus.granted => '通知已開啟',
      NotificationPermissionStatus.denied => '通知權限未開啟',
      NotificationPermissionStatus.unavailable => '此裝置未提供通知權限',
    };
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openNotificationSettings() async {
    final opened = await _notificationPermission.openSettings();
    if (!mounted || opened) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('暫時未能開啟通知設定')),
    );
  }

  Widget _buildProgressChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.38)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _buildDailyTaskRow(PlayerDailyTaskSummary task) {
    final theme = Theme.of(context);
    final color = task.isCompleted ? Colors.teal : theme.colorScheme.primary;
    return Semantics(
      container: true,
      label: dailyTaskSemanticsLabel(
        title: task.title,
        current: task.current,
        target: task.target,
        rewardCoins: task.rewardCoins,
        isCompleted: task.isCompleted,
        isClaimed: task.isClaimed,
        canClaim: task.canClaim,
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Icon(
              task.isCompleted
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              color: color,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          task.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        '${task.current}/${task.target}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Semantics(
                    container: true,
                    label: dailyTaskProgressSemanticsLabel(
                      title: task.title,
                      current: task.current,
                      target: task.target,
                    ),
                    value: '${task.current}/${task.target}',
                    child: ExcludeSemantics(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: task.progress,
                          minHeight: 6,
                          color: color,
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (task.canClaim)
              Semantics(
                container: true,
                button: true,
                label: dailyTaskClaimSemanticsLabel(
                  title: task.title,
                  rewardCoins: task.rewardCoins,
                ),
                onTap: () => _claimDailyTaskReward(task),
                child: ExcludeSemantics(
                  child: FilledButton.tonal(
                    onPressed: () => _claimDailyTaskReward(task),
                    child: Text('+${task.rewardCoins}'),
                  ),
                ),
              )
            else if (task.isClaimed)
              Semantics(
                label: dailyTaskClaimedSemanticsLabel(
                  title: task.title,
                  rewardCoins: task.rewardCoins,
                ),
                child: const Text(
                  '已領',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              )
            else
              Text(
                '+${task.rewardCoins}',
                style: theme.textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarPreview() {
    final equippedNames = _avatarState.equipped.values
        .map((id) => _shopItemById[id]?.name)
        .whereType<String>()
        .toList();
    final selectedSlot = _equipmentSlotDefs.firstWhere(
      (slot) => slot.id == _selectedEquipmentSlot,
      orElse: () => _equipmentSlotDefs.first,
    );
    final selectedItemId = _avatarState.equipped[selectedSlot.id];
    final selectedItem =
        selectedItemId == null ? null : _shopItemById[selectedItemId];

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF061824), Color(0xFF0B3B3F), Color(0xFF102515)],
        ),
        border:
            Border.all(color: const Color(0xFF6EF7D1).withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _AvatarBayPainter())),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.30),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.16)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.person,
                                color: Color(0xFF6EF7D1), size: 18),
                            const SizedBox(width: 6),
                            Text(
                              '角色裝備',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFFFFD166).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                              color: const Color(0xFFFFD166)
                                  .withValues(alpha: 0.50)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.monetization_on,
                                color: Color(0xFFFFD166), size: 18),
                            const SizedBox(width: 5),
                            Text(
                              '${_avatarState.coins}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: 356,
                    height: 410,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          bottom: 34,
                          child: Container(
                            width: 150,
                            height: 24,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              color: Colors.black.withValues(alpha: 0.34),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF6EF7D1)
                                      .withValues(alpha: 0.16),
                                  blurRadius: 22,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Container(
                          width: 222,
                          height: 310,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                const Color(0xFF6EF7D1).withValues(alpha: 0.22),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          top: 74,
                          child: AvatarLayeredPreview(
                            avatarState: _avatarState,
                            size: 238,
                          ),
                        ),
                        for (final slot in _equipmentSlotDefs)
                          _buildEquipmentPlacement(slot),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildSelectedEquipmentPanel(selectedSlot),
                  const SizedBox(height: 8),
                  Text(
                    equippedNames.isEmpty
                        ? '點擊周圍裝備槽，替角色穿裝備'
                        : '已裝備 ${equippedNames.length} 件｜點擊裝備槽更換',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.68),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (selectedItem != null)
                    Text(
                      selectedItem.effectDescription,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF6EF7D1),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEquipmentPlacement(_EquipmentSlotDef slot) {
    final itemId = _avatarState.equipped[slot.id];
    final item = itemId == null ? null : _shopItemById[itemId];
    final selected = _selectedEquipmentSlot == slot.id;
    final rarityColor =
        item == null ? const Color(0xFF6EF7D1) : _rarityColorForTier(item.tier);

    return Positioned(
      left: slot.left,
      top: slot.top,
      child: Semantics(
        button: true,
        excludeSemantics: true,
        label: profileEquipmentSlotSemanticsLabel(
          slotLabel: slot.label,
          equippedItemName: item?.name,
          selected: selected,
        ),
        onTap: () => _openEquipmentPicker(slot),
        child: Tooltip(
          message: '點按選擇${slot.label}${item == null ? '' : '：${item.name}'}',
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => _openEquipmentPicker(slot),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 72,
              height: 72,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: selected
                      ? [
                          rarityColor.withValues(alpha: 0.90),
                          const Color(0xFF0B1D24)
                        ]
                      : [const Color(0xFF163944), const Color(0xFF06151B)],
                ),
                border: Border.all(
                  color: selected
                      ? Colors.white
                      : rarityColor.withValues(alpha: 0.72),
                  width: selected ? 3 : 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        rarityColor.withValues(alpha: selected ? 0.42 : 0.20),
                    blurRadius: selected ? 18 : 10,
                    spreadRadius: selected ? 2 : 0,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.40),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (item == null)
                    Icon(slot.icon,
                        size: 28, color: Colors.white.withValues(alpha: 0.88))
                  else
                    ClipOval(
                      child: Transform.scale(
                        scale: 1.35,
                        child: Image.asset(
                          _assetForItemId(item.id),
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) =>
                              Icon(slot.icon, size: 28, color: Colors.white),
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        slot.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openEquipmentPicker(_EquipmentSlotDef slot) async {
    setState(() => _selectedEquipmentSlot = slot.id);
    final items = _shopItems.where((item) => item.slot == slot.id).toList();

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, sheetSetState) {
            final equippedItemId = _avatarState.equipped[slot.id];
            return SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  Row(
                    children: [
                      Icon(slot.icon),
                      const SizedBox(width: 8),
                      Text(
                        '選擇${slot.label}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (final item in items)
                    _buildEquipmentPickerTile(
                      item,
                      equipped: equippedItemId == item.id,
                      sheetSetState: sheetSetState,
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEquipmentPickerTile(
    _ShopItem item, {
    required bool equipped,
    required StateSetter sheetSetState,
  }) {
    final owned = _avatarState.ownedItemIds.contains(item.id);
    return Card(
      color: equipped
          ? Colors.cyan.withValues(alpha: 0.16)
          : Theme.of(context).cardColor,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minLeadingWidth: 86,
        leading: _EquipmentAssetThumb(item: item),
        title: Text(item.name),
        subtitle: Text(
            '${item.rarityLabel}｜${item.price} 金幣｜${item.effectDescription}'),
        trailing: equipped
            ? const Icon(Icons.check_circle, color: Colors.cyan)
            : Text(owned ? '裝備' : '購買'),
        onTap: () async {
          if (owned) {
            await _equipItem(item);
          } else {
            await _buyItem(item);
          }
          sheetSetState(() {});
        },
      ),
    );
  }

  Widget _buildSelectedEquipmentPanel(_EquipmentSlotDef slot) {
    final equippedItemId = _avatarState.equipped[slot.id];
    final equippedItem =
        equippedItemId == null ? null : _shopItemById[equippedItemId];
    final rarityColor = equippedItem == null
        ? const Color(0xFF6EF7D1)
        : _rarityColorForTier(equippedItem.tier);

    return Semantics(
      button: true,
      excludeSemantics: true,
      label: profileEquipmentSlotSemanticsLabel(
        slotLabel: slot.label,
        equippedItemName: equippedItem?.name,
        selected: true,
      ),
      onTap: () => _openEquipmentPicker(slot),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openEquipmentPicker(slot),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.36),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: rarityColor.withValues(alpha: 0.55)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: rarityColor.withValues(alpha: 0.18),
                  border:
                      Border.all(color: rarityColor.withValues(alpha: 0.70)),
                ),
                child: Icon(slot.icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '正在調整：${slot.label}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      equippedItem == null ? '未裝備｜點擊選擇' : equippedItem.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.70),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: rarityColor.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  '更換',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileActionPanel() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('角色與商店', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _openCharacterSettings,
              icon: const Icon(Icons.tune),
              label: const Text('角色設定'),
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: _openEquipmentShop,
              icon: const Icon(Icons.storefront),
              label: const Text('裝備商店'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _openGameItemShop,
              icon: const Icon(Icons.shopping_bag),
              label: const Text('釣魚道具商城'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openCharacterSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (routeContext) => StatefulBuilder(
          builder: (routeContext, routeSetState) => Scaffold(
            appBar: AppBar(title: const Text('角色設定')),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildAvatarPreview(),
                const SizedBox(height: 16),
                _buildCustomizationPanel(routeSetState: routeSetState),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openEquipmentShop() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (routeContext) => StatefulBuilder(
          builder: (routeContext, routeSetState) => Scaffold(
            appBar: AppBar(title: const Text('裝備商店')),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildAvatarPreview(),
                const SizedBox(height: 16),
                _buildShopPanel(routeSetState: routeSetState),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openGameItemShop() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (routeContext) => StatefulBuilder(
          builder: (routeContext, routeSetState) => Scaffold(
            appBar: AppBar(title: const Text('釣魚道具商城')),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [_buildGameItemShopPanel(routeSetState: routeSetState)],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomizationPanel({StateSetter? routeSetState}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('角色自訂',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            _buildChoiceRow('性別', _genderOptions, _avatarState.selectedGender,
                routeSetState: routeSetState),
            const SizedBox(height: 12),
            _buildPresetRow(routeSetState: routeSetState),
          ],
        ),
      ),
    );
  }

  Widget _buildChoiceRow(
    String label,
    List<String> options,
    String selected, {
    StateSetter? routeSetState,
  }) {
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
                    'gender',
                    option,
                    routeSetState: routeSetState,
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildPresetRow({StateSetter? routeSetState}) {
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
                    routeSetState?.call(() {});
                    await _saveAvatarState();
                  },
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildShopPanel({StateSetter? routeSetState}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('裝備商店',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('可購買並裝備到外圍裝備槽：魚竿、釣箱、冰箱、上衣、褲、鞋、帽、防曬面罩'),
            const SizedBox(height: 12),
            ..._shopItems.map((item) =>
                _buildShopItemTile(item, routeSetState: routeSetState)),
          ],
        ),
      ),
    );
  }

  Widget _buildShopItemTile(_ShopItem item, {StateSetter? routeSetState}) {
    final owned = _avatarState.ownedItemIds.contains(item.id);
    final equipped = _avatarState.equipped[item.slot] == item.id;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      minLeadingWidth: 86,
      leading: _EquipmentAssetThumb(item: item),
      title: Text(item.name),
      subtitle: Text(
        '分類：${item.slotLabel}  •  價格：${item.price} 金幣\n稀有度：${item.rarityLabel}\n效果：${item.effectDescription}',
      ),
      trailing: owned
          ? FilledButton.tonal(
              onPressed: equipped
                  ? null
                  : () => _equipItem(item, routeSetState: routeSetState),
              child: Text(equipped ? '已裝備' : '裝備'),
            )
          : FilledButton(
              onPressed: () => _buyItem(item, routeSetState: routeSetState),
              child: const Text('購買'),
            ),
    );
  }

  Widget _buildGameItemShopPanel({StateSetter? routeSetState}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('釣魚道具商城',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text('魚餌、誘餌、探測器與掃描券用於釣點刷魚、解鎖灰章及相片驗證活動。'),
            const SizedBox(height: 12),
            ...gameShopItems.map((item) =>
                _buildGameShopItemTile(item, routeSetState: routeSetState)),
          ],
        ),
      ),
    );
  }

  Widget _buildGameShopItemTile(GameShopItem item,
      {StateSetter? routeSetState}) {
    final owned = _gameConsumables[item.id] ?? 0;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Text(item.icon, style: const TextStyle(fontSize: 28)),
      title: Text(item.name),
      subtitle: Text('${item.category}｜持有 $owned｜${item.description}'),
      trailing: FilledButton(
        onPressed: () => _buyGameItem(item),
        child: Text('${item.price} 金幣'),
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
            const Text('金幣來源明細',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
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

class _EquipmentAssetThumb extends StatelessWidget {
  const _EquipmentAssetThumb({required this.item});

  final _ShopItem item;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 76,
      height: 76,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Transform.scale(
        scale: 1.45,
        child: Image.asset(
          _assetForItemId(item.id),
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Icon(
            _iconForEquipmentSlot(item.slot),
            color: colorScheme.primary,
            size: 34,
          ),
        ),
      ),
    );
  }
}

IconData _iconForEquipmentSlot(String slot) {
  return switch (slot) {
    'rod' => Icons.phishing,
    'tackle_box' => Icons.inventory_2,
    'cooler' => Icons.ac_unit,
    'hat' => Icons.sports_baseball,
    'mask' => Icons.wb_sunny,
    'shirt' => Icons.checkroom,
    'pants' => Icons.accessibility_new,
    'shoes' => Icons.directions_walk,
    _ => Icons.category,
  };
}

class _AvatarBayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.035)
      ..strokeWidth = 1;
    for (double x = -size.height; x < size.width; x += 28) {
      canvas.drawLine(
          Offset(x, 0), Offset(x + size.height, size.height), gridPaint);
    }
    for (double x = 0; x < size.width + size.height; x += 28) {
      canvas.drawLine(
          Offset(x, 0), Offset(x - size.height, size.height), gridPaint);
    }

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFF6EF7D1).withValues(alpha: 0.20);
    canvas.drawCircle(
        Offset(size.width / 2, size.height * 0.45), 118, ringPaint);
    canvas.drawCircle(
      Offset(size.width / 2, size.height * 0.45),
      154,
      ringPaint..color = const Color(0xFFFFD166).withValues(alpha: 0.12),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class AvatarLayeredPreview extends StatelessWidget {
  const AvatarLayeredPreview({
    super.key,
    required this.avatarState,
    this.size = 96,
  });

  final AvatarProfileViewState avatarState;
  final double size;

  @override
  Widget build(BuildContext context) {
    final bodyAsset = avatarBodyAssetFor(avatarState);

    final frameHeight = size;
    final frameWidth = size * 2 / 3;

    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: SizedBox(
          width: frameWidth,
          height: frameHeight,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _layer(bodyAsset),
              // Hair layer removed: avatar presets now provide the full clean head.
              // Equipment is intentionally NOT layered onto the body.
              // The generated equipment art is full-canvas and causes visual overlap;
              // show equipped items only in the surrounding equipment slots.
            ],
          ),
        ),
      ),
    );
  }

  Widget _layer(String path) {
    return Image.asset(
      path,
      fit: BoxFit.fill,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
  }
}

String avatarBodyAssetFor(AvatarProfileViewState avatarState) {
  final requestedPreset = avatarState.selectedPreset.clamp(1, 5);
  // Presets 2-5 are legacy placeholder PNGs. Keep the chosen gender visible
  // with the production-ready body until their full character art is ready.
  final preset = requestedPreset == 1 ? requestedPreset : 1;
  return avatarState.selectedGender == 'female'
      ? 'assets/avatar/layers/body_female_0$preset.png'
      : 'assets/avatar/layers/body_male_0$preset.png';
}

String avatarMapBodyAssetFor(AvatarProfileViewState avatarState) =>
    avatarState.selectedGender == 'female'
        ? 'assets/avatar/layers/body_female_map.png'
        : 'assets/avatar/layers/body_male_map.png';

String _assetForItemId(String itemId) => 'assets/avatar/layers/$itemId.png';

Color _rarityColorForTier(int tier) => switch (tier) {
      >= 6 => const Color(0xFFFFD166),
      5 => const Color(0xFFFF7A90),
      4 => const Color(0xFFC084FC),
      3 => const Color(0xFF60A5FA),
      2 => const Color(0xFF34D399),
      _ => const Color(0xFF6EF7D1),
    };

class _EquipmentSlotDef {
  const _EquipmentSlotDef({
    required this.id,
    required this.label,
    required this.icon,
    required this.left,
    required this.top,
  });

  final String id;
  final String label;
  final IconData icon;
  final double left;
  final double top;
}

const _equipmentSlotDefs = <_EquipmentSlotDef>[
  _EquipmentSlotDef(
      id: 'hat', label: '帽', icon: Icons.sports_baseball, left: 131, top: 12),
  _EquipmentSlotDef(
      id: 'mask', label: '防曬面罩', icon: Icons.no_accounts, left: 220, top: 62),
  _EquipmentSlotDef(
      id: 'rod', label: '魚竿', icon: Icons.phishing, left: 250, top: 142),
  _EquipmentSlotDef(
      id: 'cooler', label: '冰箱', icon: Icons.ac_unit, left: 224, top: 232),
  _EquipmentSlotDef(
      id: 'shoes',
      label: '鞋',
      icon: Icons.directions_walk,
      left: 131,
      top: 264),
  _EquipmentSlotDef(
      id: 'tackle_box',
      label: '釣箱',
      icon: Icons.inventory_2,
      left: 38,
      top: 232),
  _EquipmentSlotDef(
      id: 'shirt', label: '上身', icon: Icons.checkroom, left: 10, top: 142),
  _EquipmentSlotDef(
      id: 'pants',
      label: '下身',
      icon: Icons.accessibility_new,
      left: 38,
      top: 62),
];

const _genderOptions = ['male', 'female'];
const _presetOptions = [1, 2, 3, 4, 5];

class AvatarProfileViewState {
  const AvatarProfileViewState({
    required this.selectedGender,
    required this.selectedHairStyle,
    required this.selectedPreset,
    required this.coins,
    required this.ownedItemIds,
    required this.equipped,
  });

  factory AvatarProfileViewState.initial() => const AvatarProfileViewState(
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

  factory AvatarProfileViewState.fromEquipped(Map<String, String> equipped) =>
      AvatarProfileViewState.initial().copyWith(equipped: equipped);

  factory AvatarProfileViewState.fromMap(Map<String, dynamic> map) =>
      AvatarProfileViewState(
        selectedGender: (() {
          final g = (map['selectedGender'] as String?) ?? 'male';
          return _genderOptions.contains(g) ? g : 'male';
        })(),
        selectedHairStyle: (map['selectedHairStyle'] as String?) ?? 'short',
        selectedPreset:
            ((map['selectedPreset'] as num?)?.toInt() ?? 1).clamp(1, 5),
        coins: (map['coins'] as num?)?.toInt() ?? 500,
        ownedItemIds:
            Set<String>.from((map['ownedItemIds'] as List?) ?? const []),
        equipped:
            Map<String, String>.from((map['equipped'] as Map?) ?? const {}),
      );

  final String selectedGender;
  final String selectedHairStyle;
  final int selectedPreset;
  final int coins;
  final Set<String> ownedItemIds;
  final Map<String, String> equipped;

  AvatarProfileViewState copyWith({
    String? selectedGender,
    String? selectedHairStyle,
    int? selectedPreset,
    int? coins,
    Set<String>? ownedItemIds,
    Map<String, String>? equipped,
  }) =>
      AvatarProfileViewState(
        selectedGender: selectedGender ?? this.selectedGender,
        selectedHairStyle: selectedHairStyle ?? this.selectedHairStyle,
        selectedPreset: selectedPreset ?? this.selectedPreset,
        coins: coins ?? this.coins,
        ownedItemIds: ownedItemIds ?? this.ownedItemIds,
        equipped: equipped ?? this.equipped,
      );

  AvatarProfileViewState copyWithOption(String key, String value) {
    if (key == 'gender') return copyWith(selectedGender: value);
    if (key == 'hair') return copyWith(selectedHairStyle: value);
    return this;
  }

  AvatarProfileViewState purchase(String itemId, int price) {
    final nextOwned = Set<String>.from(ownedItemIds)..add(itemId);
    return copyWith(coins: coins - price, ownedItemIds: nextOwned);
  }

  AvatarProfileViewState equip(String slot, String itemId) {
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

  int get tier {
    if (id.endsWith('_06')) return 6;
    if (id.endsWith('_05')) return 5;
    if (id.endsWith('_04')) return 4;
    if (id.endsWith('_03')) return 3;
    if (id.endsWith('_02')) return 2;
    return 1;
  }

  String get effectDescription {
    final t = tier;
    return switch (slot) {
      'rod' => '成功判定區 +${t * 3}%，拉竿更容易。',
      'tackle_box' => '釣獲金幣 +${t * 2}，提高刷釣點收益。',
      'cooler' => '稀有魚權重 +${t * 4}%，高價魚更易出現。',
      'hat' => '指針速度 -${t * 2}%，更容易看準時機。',
      'mask' => '防曬耐力 +${t * 2}%，烈日釣點失手容錯提高。',
      'shirt' => '穩定度 +${t * 2}%，成功區額外放寬。',
      'pants' => '耐力 +${t * 2}%，高稀有魚挑戰較穩。',
      'shoes' => '移動效率 +${t * 2}%，釣點探索獎勵提升。',
      _ => '提供少量釣魚輔助。',
    };
  }
}

const _shopItems = <_ShopItem>[
  _ShopItem(
      id: 'hat_01',
      name: '碼頭鴨舌帽',
      price: 120,
      slot: 'hat',
      slotLabel: '帽',
      rarityLabel: '初級'),
  _ShopItem(
      id: 'hat_02',
      name: '潮汐遮陽帽',
      price: 180,
      slot: 'hat',
      slotLabel: '帽',
      rarityLabel: '初級'),
  _ShopItem(
      id: 'hat_03',
      name: '浪花漁夫帽',
      price: 320,
      slot: 'hat',
      slotLabel: '帽',
      rarityLabel: '中級'),
  _ShopItem(
      id: 'hat_04',
      name: '海港巡邏帽',
      price: 450,
      slot: 'hat',
      slotLabel: '帽',
      rarityLabel: '中級'),
  _ShopItem(
      id: 'hat_05',
      name: '黃金船長帽',
      price: 800,
      slot: 'hat',
      slotLabel: '帽',
      rarityLabel: '高級'),
  _ShopItem(
      id: 'hat_06',
      name: '星耀海神冠',
      price: 1200,
      slot: 'hat',
      slotLabel: '帽',
      rarityLabel: '傳說'),
  _ShopItem(
      id: 'mask_01',
      name: '清風防曬面罩',
      price: 120,
      slot: 'mask',
      slotLabel: '防曬面罩',
      rarityLabel: '初級'),
  _ShopItem(
      id: 'mask_02',
      name: '海霧防曬面罩',
      price: 180,
      slot: 'mask',
      slotLabel: '防曬面罩',
      rarityLabel: '初級'),
  _ShopItem(
      id: 'mask_03',
      name: '珊瑚護面罩',
      price: 320,
      slot: 'mask',
      slotLabel: '防曬面罩',
      rarityLabel: '中級'),
  _ShopItem(
      id: 'mask_04',
      name: '浪影防曬面罩',
      price: 450,
      slot: 'mask',
      slotLabel: '防曬面罩',
      rarityLabel: '中級'),
  _ShopItem(
      id: 'mask_05',
      name: '極光防曬面罩',
      price: 800,
      slot: 'mask',
      slotLabel: '防曬面罩',
      rarityLabel: '高級'),
  _ShopItem(
      id: 'mask_06',
      name: '龍鱗防曬面罩',
      price: 1200,
      slot: 'mask',
      slotLabel: '防曬面罩',
      rarityLabel: '傳說'),
  _ShopItem(
      id: 'shirt_01',
      name: '碼頭背心',
      price: 120,
      slot: 'shirt',
      slotLabel: '上衣',
      rarityLabel: '初級'),
  _ShopItem(
      id: 'shirt_02',
      name: '潮汐速乾衫',
      price: 180,
      slot: 'shirt',
      slotLabel: '上衣',
      rarityLabel: '初級'),
  _ShopItem(
      id: 'shirt_03',
      name: '礁石釣手衣',
      price: 320,
      slot: 'shirt',
      slotLabel: '上衣',
      rarityLabel: '中級'),
  _ShopItem(
      id: 'shirt_04',
      name: '海風戰術外套',
      price: 450,
      slot: 'shirt',
      slotLabel: '上衣',
      rarityLabel: '中級'),
  _ShopItem(
      id: 'shirt_05',
      name: '金鱗船長外套',
      price: 800,
      slot: 'shirt',
      slotLabel: '上衣',
      rarityLabel: '高級'),
  _ShopItem(
      id: 'shirt_06',
      name: '深海龍紋戰衣',
      price: 1200,
      slot: 'shirt',
      slotLabel: '上衣',
      rarityLabel: '傳說'),
  _ShopItem(
      id: 'pants_01',
      name: '輕便短褲',
      price: 120,
      slot: 'pants',
      slotLabel: '褲',
      rarityLabel: '初級'),
  _ShopItem(
      id: 'pants_02',
      name: '防水釣魚褲',
      price: 180,
      slot: 'pants',
      slotLabel: '褲',
      rarityLabel: '初級'),
  _ShopItem(
      id: 'pants_03',
      name: '礁岸機能褲',
      price: 320,
      slot: 'pants',
      slotLabel: '褲',
      rarityLabel: '中級'),
  _ShopItem(
      id: 'pants_04',
      name: '浪潮護膝長褲',
      price: 450,
      slot: 'pants',
      slotLabel: '褲',
      rarityLabel: '中級'),
  _ShopItem(
      id: 'pants_05',
      name: '黃金遠征褲',
      price: 800,
      slot: 'pants',
      slotLabel: '褲',
      rarityLabel: '高級'),
  _ShopItem(
      id: 'pants_06',
      name: '深海鱗甲長褲',
      price: 1200,
      slot: 'pants',
      slotLabel: '褲',
      rarityLabel: '傳說'),
  _ShopItem(
      id: 'shoes_01',
      name: '防滑膠鞋',
      price: 120,
      slot: 'shoes',
      slotLabel: '鞋',
      rarityLabel: '初級'),
  _ShopItem(
      id: 'shoes_02',
      name: '浪花快步鞋',
      price: 180,
      slot: 'shoes',
      slotLabel: '鞋',
      rarityLabel: '初級'),
  _ShopItem(
      id: 'shoes_03',
      name: '礁石抓地鞋',
      price: 320,
      slot: 'shoes',
      slotLabel: '鞋',
      rarityLabel: '中級'),
  _ShopItem(
      id: 'shoes_04',
      name: '潮汐疾行鞋',
      price: 450,
      slot: 'shoes',
      slotLabel: '鞋',
      rarityLabel: '中級'),
  _ShopItem(
      id: 'shoes_05',
      name: '黃金航海靴',
      price: 800,
      slot: 'shoes',
      slotLabel: '鞋',
      rarityLabel: '高級'),
  _ShopItem(
      id: 'shoes_06',
      name: '海神踏浪靴',
      price: 1200,
      slot: 'shoes',
      slotLabel: '鞋',
      rarityLabel: '傳說'),
  _ShopItem(
      id: 'rod_01',
      name: '竹影手竿',
      price: 120,
      slot: 'rod',
      slotLabel: '魚竿',
      rarityLabel: '初級'),
  _ShopItem(
      id: 'rod_02',
      name: '港灣輕竿',
      price: 180,
      slot: 'rod',
      slotLabel: '魚竿',
      rarityLabel: '初級'),
  _ShopItem(
      id: 'rod_03',
      name: '銀浪碳纖竿',
      price: 320,
      slot: 'rod',
      slotLabel: '魚竿',
      rarityLabel: '中級'),
  _ShopItem(
      id: 'rod_04',
      name: '雷鳴遠投竿',
      price: 450,
      slot: 'rod',
      slotLabel: '魚竿',
      rarityLabel: '中級'),
  _ShopItem(
      id: 'rod_05',
      name: '黃金龍鬚竿',
      price: 800,
      slot: 'rod',
      slotLabel: '魚竿',
      rarityLabel: '高級'),
  _ShopItem(
      id: 'rod_06',
      name: '星海神釣竿',
      price: 1200,
      slot: 'rod',
      slotLabel: '魚竿',
      rarityLabel: '傳說'),
  _ShopItem(
      id: 'tackle_box_01',
      name: '小海灣釣箱',
      price: 120,
      slot: 'tackle_box',
      slotLabel: '釣箱',
      rarityLabel: '初級'),
  _ShopItem(
      id: 'tackle_box_02',
      name: '藍潮分類箱',
      price: 180,
      slot: 'tackle_box',
      slotLabel: '釣箱',
      rarityLabel: '初級'),
  _ShopItem(
      id: 'tackle_box_03',
      name: '礁石工具箱',
      price: 320,
      slot: 'tackle_box',
      slotLabel: '釣箱',
      rarityLabel: '中級'),
  _ShopItem(
      id: 'tackle_box_04',
      name: '海港戰術釣箱',
      price: 450,
      slot: 'tackle_box',
      slotLabel: '釣箱',
      rarityLabel: '中級'),
  _ShopItem(
      id: 'tackle_box_05',
      name: '黃金寶藏釣箱',
      price: 800,
      slot: 'tackle_box',
      slotLabel: '釣箱',
      rarityLabel: '高級'),
  _ShopItem(
      id: 'tackle_box_06',
      name: '深海秘寶釣箱',
      price: 1200,
      slot: 'tackle_box',
      slotLabel: '釣箱',
      rarityLabel: '傳說'),
  _ShopItem(
      id: 'cooler_01',
      name: '迷你保鮮箱',
      price: 120,
      slot: 'cooler',
      slotLabel: '冰箱',
      rarityLabel: '初級'),
  _ShopItem(
      id: 'cooler_02',
      name: '冰藍冷藏箱',
      price: 180,
      slot: 'cooler',
      slotLabel: '冰箱',
      rarityLabel: '初級'),
  _ShopItem(
      id: 'cooler_03',
      name: '珊瑚保冷箱',
      price: 320,
      slot: 'cooler',
      slotLabel: '冰箱',
      rarityLabel: '中級'),
  _ShopItem(
      id: 'cooler_04',
      name: '極地漁獲箱',
      price: 450,
      slot: 'cooler',
      slotLabel: '冰箱',
      rarityLabel: '中級'),
  _ShopItem(
      id: 'cooler_05',
      name: '黃金冷鏈箱',
      price: 800,
      slot: 'cooler',
      slotLabel: '冰箱',
      rarityLabel: '高級'),
  _ShopItem(
      id: 'cooler_06',
      name: '龍宮寒冰箱',
      price: 1200,
      slot: 'cooler',
      slotLabel: '冰箱',
      rarityLabel: '傳說'),
];

final _shopItemById = {for (final item in _shopItems) item.id: item};
