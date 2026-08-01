import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import 'update_platform.dart';

/// Shows a non-dismissable overlay when a new app version is available.
class UpdatePromptOverlay extends StatelessWidget {
  const UpdatePromptOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Material(
        color: Colors.black87,
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(32),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A5F),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.cyanAccent, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.system_update,
                    color: Colors.cyanAccent, size: 56),
                const SizedBox(height: 16),
                const Text(
                  '新版本已發佈 🎉',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '請更新至最新版本，\n享受最新功能和修正',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 15),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: reloadApp,
                  icon: const Icon(Icons.refresh),
                  label: const Text('立即更新'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 14),
                    backgroundColor: Colors.cyan,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Checks if index.html has changed since last run using localStorage.
/// Shows [UpdatePromptOverlay] if a new build is detected.
Future<void> checkForAppUpdate(BuildContext context) async {
  try {
    const boxName = 'update_box';
    final b = await Hive.openBox(boxName);
    final lastBuild =
        (b.get('build_number', defaultValue: 0) as num?)?.toInt() ?? 0;

    final currentBuild = await fetchCurrentBuildNumber();

    if (shouldPromptForAppUpdate(
          lastBuild: lastBuild,
          currentBuild: currentBuild,
        ) &&
        context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const UpdatePromptOverlay()),
      );
    }

    if (currentBuild > 0) await b.put('build_number', currentBuild);
  } catch (_) {}
}

bool shouldPromptForAppUpdate({
  required int lastBuild,
  required int currentBuild,
}) =>
    lastBuild > 0 && currentBuild > lastBuild;
