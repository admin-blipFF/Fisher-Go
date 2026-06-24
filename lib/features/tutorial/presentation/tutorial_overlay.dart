import 'package:flutter/material.dart';

import '../../../core/tutorial/tutorial_service.dart';

/// Tutorial overlay widget with 4 steps.
///
/// Step 0: Welcome
/// Step 1: GPS instruction
/// Step 2: Forced fishing (not skippable) — button triggers fish-010 catch
/// Step 3: Completion
class TutorialOverlay extends StatefulWidget {
  const TutorialOverlay({
    super.key,
    required this.onStartFishing,
    required this.onComplete,
  });

  final VoidCallback onStartFishing;
  final VoidCallback onComplete;

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay> {
  static const int _totalSteps = 4;

  int _currentStep = 0;
  final bool _forceFishingDone = false;

  // Tutorial fish constants
  static const String _tutorialFishId = 'fish-010';
  static const String _tutorialFishName = '白䱛';

  void _onForceFishingTap() {
    widget.onStartFishing();
  }

  Future<void> _onComplete() async {
    await TutorialService.markCompleted();
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: Stack(
        children: [
          // Step indicator
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 0,
            right: 0,
            child: _StepIndicator(
              current: _currentStep,
              total: _totalSteps,
            ),
          ),
          // Content card
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: _buildStepContent(),
            ),
          ),
          // Navigation buttons (bottom)
          if (!_forceFishingDone || _currentStep < 3)
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.of(context).padding.bottom + 32,
              child: _buildNavButtons(),
            ),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _WelcomeStep();
      case 1:
        return _GpsStep();
      case 2:
        return _ForceFishingStep(
          done: _forceFishingDone,
          fishId: _tutorialFishId,
          fishName: _tutorialFishName,
          onTap: _onForceFishingTap,
        );
      case 3:
        return _CompleteStep(
          fishId: _tutorialFishId,
          fishName: _tutorialFishName,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildNavButtons() {
    // Step 2 is NOT skippable — no Back/Next there
    if (_currentStep == 2) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentStep > 0)
            TextButton(
              onPressed: () => setState(() => _currentStep--),
              child: const Text(
                '返回',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            )
          else
            const SizedBox(width: 60),
          if (_currentStep < _totalSteps - 1)
            FilledButton(
              onPressed: () => setState(() => _currentStep++),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.teal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              ),
              child: const Text('下一步', style: TextStyle(fontSize: 16)),
            )
          else
            FilledButton(
              onPressed: _onComplete,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.teal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              ),
              child: const Text('完成', style: TextStyle(fontSize: 16)),
            ),
        ],
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int current;
  final int total;

  const _StepIndicator({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (index) {
        final isActive = index == current;
        final isPast = index < current;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: isActive
                ? Colors.tealAccent
                : isPast
                    ? Colors.teal.withValues(alpha: 0.6)
                    : Colors.white24,
          ),
        );
      }),
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      const Text(
        '👋',
        style: TextStyle(fontSize: 64),
      ),
      const SizedBox(height: 16),
      const Text(
        '你好！歡迎來到 FisherGO！',
        style: TextStyle(
          color: Colors.white,
          fontSize: 26,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 12),
      const Text(
        '圖鑑內有多種香港魚類，等你慢慢發掘',
        style: TextStyle(color: Colors.white70, fontSize: 16),
        textAlign: TextAlign.center,
      ),
    ]);
  }
}

class _GpsStep extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.location_on, color: Colors.cyanAccent, size: 64),
      const SizedBox(height: 16),
      const Text(
        '每次釣魚前，先確保你在合法碼頭或水域範圍內',
        style: TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 12),
      const Text(
        '地圖會顯示可釣魚的碼頭位置。到達釣點後開始作釣，可獲得釣點金幣獎勵。',
        style: TextStyle(color: Colors.white70, fontSize: 16),
        textAlign: TextAlign.center,
      ),
      const Text(
        '每個釣點每 15 分鐘可領一次 +10 金幣',
        style: TextStyle(color: Colors.amberAccent, fontSize: 13),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.cyanAccent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.3)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline, color: Colors.cyanAccent, size: 20),
            SizedBox(width: 8),
            Text(
              '請確保 GPS 定位已開啟',
              style: TextStyle(color: Colors.cyanAccent, fontSize: 14),
            ),
          ],
        ),
      ),
    ]);
  }
}

class _ForceFishingStep extends StatelessWidget {
  final bool done;
  final String fishId;
  final String fishName;
  final VoidCallback onTap;

  const _ForceFishingStep({
    required this.done,
    required this.fishId,
    required this.fishName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      if (!done) ...[
        const Icon(Icons.catching_pokemon,
            color: Colors.orangeAccent, size: 64),
        const SizedBox(height: 16),
        const Text(
          '先到碼頭，然後體驗第一桿',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        // Forced fishing button — NOT skippable
        FilledButton.icon(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.orange,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          ),
          icon: const Icon(Icons.catching_pokemon, size: 24),
          label: const Text(
            '開始釣魚 (教學)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '此步驟無法跳過，失敗會重試至成功',
          style: TextStyle(color: Colors.orangeAccent, fontSize: 12),
        ),
      ] else ...[
        const Text('🎉', style: TextStyle(fontSize: 56)),
        const SizedBox(height: 12),
        const Text(
          '又係依D!',
          style: TextStyle(
            color: Colors.orangeAccent,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        _FishCard(fishId: fishId, fishName: fishName),
      ],
    ]);
  }
}

class _CompleteStep extends StatelessWidget {
  final String fishId;
  final String fishName;

  const _CompleteStep({required this.fishId, required this.fishName});

  @override
  Widget build(BuildContext context) {
    final fishNumber = fishId.replaceFirst('fish-', '#');
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.teal.withValues(alpha: 0.15),
          shape: BoxShape.circle,
          border: Border.all(
              color: Colors.tealAccent.withValues(alpha: 0.4), width: 3),
        ),
        child: const Icon(
          Icons.check,
          color: Colors.tealAccent,
          size: 64,
        ),
      ),
      const SizedBox(height: 20),
      const Text(
        '教學完成！',
        style: TextStyle(
          color: Colors.white,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.teal.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.4)),
        ),
        child: Text(
          '$fishNumber $fishName 已解鎖！',
          style: const TextStyle(
            color: Colors.tealAccent,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      const SizedBox(height: 20),
      _FishCard(fishId: fishId, fishName: fishName),
      const SizedBox(height: 16),
      const Text(
        '圖鑑規則：遊戲釣獲會顯示灰版彩圖；真實上魚獲驗證後會變成完整彩圖。',
        style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.35),
        textAlign: TextAlign.center,
      ),
    ]);
  }
}

/// Small fish card used in tutorial result display
class _FishCard extends StatelessWidget {
  final String fishId;
  final String fishName;

  const _FishCard({required this.fishId, required this.fishName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.cyan.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child:
                const Icon(Icons.set_meal, color: Colors.cyanAccent, size: 28),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                fishName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                fishId,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(width: 8),
          const Icon(Icons.lock_open, color: Colors.tealAccent, size: 18),
        ],
      ),
    );
  }
}
