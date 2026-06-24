from pathlib import Path

p = Path('C:/Users/s0829/fishergo/lib/features/game_home/presentation/game_home_screen.dart')
s = p.read_text(encoding='utf-8')

start = s.index("    if (widget.tutorialMode) {", s.index("  void initState()"))
end = s.index("  Widget _buildFishingPhase", start)
spot_start = s.index("    return Column(mainAxisSize: MainAxisSize.min, children: [", start)
spot_body = s[spot_start:end]

methods = '''    if (widget.tutorialMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _startFishing(_allSpots[0]);
        }
      });
    }
  }

  Future<void> _loadKnownFish() async {
    final collection = await FishCollectionService.loadAllSafe();
    if (!mounted) return;
    setState(() {
      _knownFishIds = collection.entries
          .where((entry) =>
              entry.value.status.index >= FishDiscoveryStatus.gameCaught.index)
          .map((entry) => entry.key)
          .toSet();
    });
  }

  bool _hasCaughtBefore(_FishEntry? fish) {
    if (fish == null) return false;
    return _knownFishIds.contains(fish.fishId);
  }

  @override
  void dispose() {
    _resultRevealTimer?.cancel();
    _tickController.dispose();
    super.dispose();
  }

  void _onTick() {
    if (_phase != _FishingPhase.fishing) return;
    final fish = _caughtFish;
    if (fish == null) return;
    final stats = fish.stats;
    const dt = 0.05;

    setState(() {
      _tickCount++;
      _gameSeconds = (_tickCount / 20).floor();

      final lineFactor = 0.6 + 0.8 * (1 - _lineMeters / _maxLineMeters);
      if (!_fishExhausted) {
        _tension += stats.baseTension * lineFactor * dt;
      }

      if (_isSpiking) {
        _tension += stats.spikePower * 0.35 * dt;
        _spikeTimer -= dt;
        if (_spikeTimer <= 0) {
          _isSpiking = false;
          _spikeCooldown = 2.5 + _rng.nextDouble() * 2;
        }
      } else {
        _spikeCooldown -= dt;
        if (_spikeCooldown <= 0 && _fishStamina > 5) {
          final chance = (_fishStamina / _maxStamina) * 0.7 + 0.1;
          if (_rng.nextDouble() < chance) {
            _isSpiking = true;
            _spikeTimer = stats.spikeDuration;
            _fishStamina -= 8;
            if (_fishStamina <= 0) {
              _fishStamina = 0;
              _fishExhausted = true;
              _isSpiking = false;
              _spikeTimer = 0;
            }
          } else {
            _spikeCooldown = 1.0;
          }
        }
      }

      if (_isPulling) {
        final reelSpeed = _fishExhausted ? 3.2 : 1.6;
        _tension += _fishExhausted ? 8 * dt : 14 * dt;
        _lineMeters -= reelSpeed * dt;
      } else {
        _tension -= 18 * dt;
      }

      final pullOut = _fishExhausted
          ? 0.15
          : stats.baseTension * 0.22 * (_isSpiking ? 2.5 : 1.0);
      _lineMeters += pullOut * dt;

      _tension = _tension.clamp(0.0, 100.0);
      _lineMeters = _lineMeters.clamp(0.0, _maxLineMeters);

      final staminaBeforeDrain = _fishStamina;
      if (!_fishExhausted) {
        _fishStamina -= 1.2 * dt;
        if (_tension >= 30 && _tension <= 70) {
          _fishStamina -= 2.2 * dt;
        }
      }
      _fishStamina = _fishStamina.clamp(0.0, _maxStamina);
      if (staminaBeforeDrain > 0 && _fishStamina <= 0) {
        _fishExhausted = true;
        _isSpiking = false;
        _spikeTimer = 0;
      }

      _hookOffset = ((_tension - 50) / 50).clamp(-1.0, 1.0);

      if (_tension >= 95) {
        _failReason = '張力太高，魚線斷了！';
        _endGame(false);
      } else if (_lineMeters >= _maxLineMeters) {
        _failReason = '線全部放出，魚逃走了！';
        _endGame(false);
      } else if (_fishExhausted && _lineMeters <= 0) {
        _endGame(true);
      }
    });
  }

  void _endGame(bool won) {
    _resultRevealTimer?.cancel();
    _fishingResult = won;
    _showResultDetails = false;
    _phase = _FishingPhase.result;
    _tickController.stop();

    if (won && _caughtFish != null) {
      final fish = _caughtFish!;
      _checkAndLockTutorialFish(fish);
      _resultRevealTimer = Timer(const Duration(seconds: 1), () async {
        await FishCollectionService.markGameCaught(fish.fishId);
        if (!mounted) return;
        setState(() {
          _knownFishIds = {..._knownFishIds, fish.fishId};
          _showResultDetails = true;
        });
        if (widget.tutorialMode && fish.fishId == 'fish-010') {
          await TutorialService.markCompleted();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('又係依D! #010 白䱛 已解鎖'),
              backgroundColor: Colors.teal,
              duration: Duration(seconds: 2),
            ),
          );
          Future.delayed(const Duration(milliseconds: 1800), () {
            if (mounted) widget.onTutorialComplete?.call();
          });
        }
      });
    } else {
      _showResultDetails = true;
      if (widget.tutorialMode) {
        _resultRevealTimer = Timer(const Duration(milliseconds: 1200), () {
          if (!mounted) return;
          _startFishing(_selectedSpot ?? _allSpots[0]);
        });
      }
    }
  }

  Future<void> _checkAndLockTutorialFish(_FishEntry fish) async {
    final tutorialDone = await TutorialService.isCompleted();
    if (!tutorialDone && fish.fishId != 'fish-010') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('先完成教學'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _startFishing(_FishSpot spot) {
    final fish = _selectRandomFish(spot);
    final stats = fish.stats;
    setState(() {
      _selectedSpot = spot;
      _caughtFish = fish;
      _phase = _FishingPhase.fishing;
      _tension = 40.0;
      _maxStamina = stats.stamina;
      _fishStamina = stats.stamina;
      _maxLineMeters = spot.maxLineMeters.toDouble();
      final minStart = _maxLineMeters * 0.35;
      final maxStart = _maxLineMeters * 0.85;
      _lineMeters = minStart + _rng.nextDouble() * (maxStart - minStart);
      _isSpiking = false;
      _spikeTimer = 0;
      _spikeCooldown = 2.0;
      _fishExhausted = false;
      _tickCount = 0;
      _gameSeconds = 0;
      _hookOffset = 0.0;
      _visualSeed = _rng.nextDouble() * 1000;
      _fishingResult = null;
      _showResultDetails = false;
      _failReason = '';
    });
    _tickController.repeat();
  }

  void _onPullStart() {
    setState(() => _isPulling = true);
  }

  void _onPullEnd() {
    setState(() => _isPulling = false);
  }

  void _retry() {
    _resultRevealTimer?.cancel();
    setState(() {
      _phase = _FishingPhase.spotSelect;
      _caughtFish = null;
      _fishingResult = null;
      _showResultDetails = false;
    });
  }

  _FishEntry _selectRandomFish(_FishSpot spot) {
    if (widget.tutorialMode) return _tutorialFish;
    final totalWeight = spot.weights.reduce((a, b) => a + b);
    var r = _rng.nextDouble() * totalWeight;
    for (var i = 0; i < spot.fish.length; i++) {
      r -= spot.weights[i];
      if (r <= 0) return spot.fish[i];
    }
    return spot.fish.last;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      GestureDetector(onTap: () {}, child: Container(color: Colors.black87)),
      if (!widget.tutorialMode)
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          right: 8,
          child: SafeArea(
            child: IconButton.filled(
              onPressed: widget.onClose,
              icon: const Icon(Icons.close),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black54,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ),
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: _buildPhaseContent(context),
          ),
        ),
      ),
    ]);
  }

  Widget _buildPhaseContent(BuildContext context) {
    switch (_phase) {
      case _FishingPhase.spotSelect:
        return _buildSpotSelect(context);
      case _FishingPhase.fishing:
        return _buildFishingPhase(context);
      case _FishingPhase.result:
        return _buildResultPhase(context);
    }
  }

  Widget _buildSpotSelect(BuildContext context) {
    if (widget.tutorialMode) {
      return const Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.location_on, color: Colors.cyanAccent, size: 64),
        SizedBox(height: 16),
        Text(
          '教學碼頭位置',
          style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 8),
        Text(
          '三家村碼頭\\n22.291001, 114.236315',
          style: TextStyle(color: Colors.white70, fontSize: 18, height: 1.4),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 16),
        Text(
          '正在強制開啟釣魚小遊戲…\\n失敗會自動重試，直到成功釣到 #010 白䱛。',
          style: TextStyle(color: Colors.orangeAccent, fontSize: 15, height: 1.4),
          textAlign: TextAlign.center,
        ),
      ]);
    }
'''

s = s[:start] + methods + spot_body + s[end:]
p.write_text(s, encoding='utf-8')
print('repaired methods block')
