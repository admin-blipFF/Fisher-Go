import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:web/web.dart' as web;

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
                  onPressed: () => web.window.location.reload(),
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
    // Use Flutter's build timestamp (injected at build time via build_number)
    // Simple approach: store a build ID in localStorage, compare each startup
    const boxName = 'update_box';
    final b = await Hive.openBox(boxName);
    final lastBuild =
        (b.get('build_number', defaultValue: 0) as num?)?.toInt() ?? 0;

    // Read current build number from window (set by index.html injection)
    final currentBuild = _getCurrentBuildNumber();

    if (currentBuild > lastBuild && lastBuild != 0 && context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const UpdatePromptOverlay()),
      );
    }

    await b.put('build_number', currentBuild);
  } catch (_) {}
}

/// Reads build number injected by the build process.
/// Returns 0 if not found (first run).
int _getCurrentBuildNumber() {
  try {
    // The build number is set as a data attribute on <html> by our vercel.json
    // For simplicity, we use a timestamp approach:
    // A new build always has a newer timestamp in version.json
    // We read it via JS interop
    return _fetchBuildNumber();
  } catch (_) {
    return 0;
  }
}

int _fetchBuildNumber() {
  // Use JS to get build info
  // We store build number in a meta tag or window variable set by index.html
  // For now return a fixed sentinel that changes each deploy
  // (the actual build number is passed via Flutter's build_info or similar)
  try {
    // Check if version.json exists and get its timestamp
    // This is handled by Flutter's service worker but we need a web-native approach
    final doc = web.document;
    final meta = doc.querySelector('meta[name="build-ts"]');
    if (meta != null) {
      return int.tryParse(meta.getAttribute('content') ?? '') ?? 0;
    }
    // Fallback: use service worker registration timestamp
    final swMeta = doc.querySelector('meta[name="flutter-service-worker"]');
    if (swMeta != null) {
      return int.tryParse(swMeta.getAttribute('content') ?? '') ?? 0;
    }
  } catch (_) {}
  return 0;
}
