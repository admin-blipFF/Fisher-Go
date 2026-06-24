import 'package:flutter/material.dart';

import '../../../core/announcement/announcement_data.dart';
import '../../../core/announcement/announcement_service.dart';
import '../../profile/data/profile_wallet_service.dart';

/// Modal dialog showing the daily announcement.
class AnnouncementModal extends StatefulWidget {
  const AnnouncementModal({super.key});

  static Future<void> show(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (_) => const AnnouncementModal(),
    );
  }

  @override
  State<AnnouncementModal> createState() => _AnnouncementModalState();
}

class _AnnouncementModalState extends State<AnnouncementModal> {
  bool _claimed = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _checkClaimed();
  }

  Future<void> _checkClaimed() async {
    final claimed = await AnnouncementService.hasClaimedToday();
    if (mounted) setState(() => _claimed = claimed);
  }

  Future<void> _claim(BuildContext context, AnnouncementData data) async {
    if (_claimed || _loading) return;
    setState(() => _loading = true);
    try {
      await ProfileWalletService.addCoins(
        data.coinReward,
        reason: '每日公告獎勵',
      );
      await AnnouncementService.markSeen();
      await AnnouncementService.markClaimed();
      if (mounted) {
        setState(() {
          _claimed = true;
          _loading = false;
        });
        if (!context.mounted) return;
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已獲得 ${data.coinReward} 金幣！'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = AnnouncementData.todays;

    return AlertDialog(
      title: Text(data.title, style: const TextStyle(fontSize: 20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(data.body, style: const TextStyle(fontSize: 15)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _claimed ? Colors.grey.shade100 : Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _claimed ? Colors.grey.shade300 : Colors.amber.shade200,
              ),
            ),
            child: Row(
              children: [
                Text(_claimed ? '✅' : '💰',
                    style: TextStyle(
                        fontSize: 24, color: _claimed ? Colors.grey : null)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _claimed ? '今日獎勵已領取' : '今日獎勵：${data.coinReward} 金幣',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _claimed
                          ? Colors.grey.shade600
                          : Colors.amber.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('關閉'),
        ),
        if (!_claimed)
          FilledButton(
            onPressed: _loading ? null : () => _claim(context, data),
            child: _loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('領取'),
          ),
        if (_claimed)
          FilledButton(
            onPressed: null,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.grey.shade300,
              foregroundColor: Colors.grey.shade600,
            ),
            child: const Text('已領取'),
          ),
      ],
    );
  }
}
