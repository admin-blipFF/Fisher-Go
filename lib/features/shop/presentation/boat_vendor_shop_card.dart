import 'package:flutter/material.dart';

import '../../../domain/boat_vendor.dart';
import '../../../core/shop/boat_vendor_service.dart';
import '../../profile/data/profile_wallet_service.dart';

class BoatVendorShopCard extends StatelessWidget {
  const BoatVendorShopCard({
    super.key,
    required this.vendor,
    this.onRented,
  });

  final BoatVendor vendor;
  final VoidCallback? onRented;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        title: Text(
          vendor.name,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        subtitle:
            Text('${vendor.zoneName}\n路線：${vendor.spotNames.join(' > ')}'),
        trailing: FilledButton(
          onPressed: () => _rent(context),
          child: Text('${vendor.priceCoins} 金幣'),
        ),
      ),
    );
  }

  Future<void> _rent(BuildContext context) async {
    final coins = await ProfileWalletService.getCoins();
    if (coins < vendor.priceCoins) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('金幣不足，需要 ${vendor.priceCoins} 金幣')),
        );
      }
      return;
    }

    final ok = await BoatVendorService.rent(vendor.id);
    if (!ok) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('租用失敗，請重試')),
        );
      }
      return;
    }

    final dialogue = await BoatVendorService.getRandomDialogue();
    if (!context.mounted) return;

    // Show brief dialogue then navigate to route screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(dialogue != null ? '船家：$dialogue' : '租用成功！'),
        duration: const Duration(seconds: 2),
      ),
    );

    // Notify the map screen to reload the active boat vendor, switch back to
    // the map, and open the real boat-route fishing picker. The old pushed
    // route summary had no parent callback, so its 作釣 button only popped the
    // page and never opened the minigame.
    onRented?.call();
  }
}
