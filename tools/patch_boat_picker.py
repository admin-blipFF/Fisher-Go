from pathlib import Path

p = Path('C:/Users/s0829/fishergo/lib/features/game_home/presentation/game_home_screen.dart')
s = p.read_text(encoding='utf-8')

# Add active vendor state
s = s.replace(
    "  bool _isAtBoatSpot = false;\n  List<LatLng> _cachedBoatSpots = [];",
    "  bool _isAtBoatSpot = false;\n  BoatVendor? _activeBoatVendor;\n  List<LatLng> _cachedBoatSpots = [];",
)

# Init load active vendor
s = s.replace(
    "      _checkAnnouncementBadge();\n    });",
    "      _checkAnnouncementBadge();\n      _loadActiveBoatVendor();\n    });",
)

# Add method after checkAnnouncementBadge
marker = """  Future<void> _checkAnnouncementBadge() async {
    final unseen = await AnnouncementService.hasUnseen();
    if (mounted) {
      setState(() => _showAnnouncementRedDot = unseen);
    }
  }
"""
insert = marker + """
  Future<void> _loadActiveBoatVendor() async {
    final vendor = await BoatVendorService.getActiveVendor();
    if (!mounted) return;
    setState(() => _activeBoatVendor = vendor);
  }

  void _showBoatSpotPicker() {
    final vendor = _activeBoatVendor;
    if (vendor == null) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF102033),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '船家 ${vendor.name} · 選擇釣點',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '按路線順序選擇一個釣點，不需 GPS。',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 12),
              ...List.generate(vendor.spotLocations.length, (index) {
                final pos = vendor.spotLocations[index];
                final name = index < vendor.spotNames.length
                    ? vendor.spotNames[index]
                    : '船家釣點 ${index + 1}';
                return Card(
                  color: const Color(0xFF193047),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.teal,
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      '${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
                    ),
                    trailing: const Icon(Icons.phishing, color: Colors.cyanAccent),
                    onTap: () async {
                      Navigator.of(context).pop();
                      final dialogue = await BoatVendorService.getRandomDialogue();
                      if (!mounted) return;
                      final spot = _SpotDemo(
                        pos.latitude,
                        pos.longitude,
                        name,
                        3,
                        false,
                      );
                      setState(() {
                        _selectedSpot = spot;
                        _playerLatLng = pos;
                        _hasLiveLocation = true;
                      });
                      _mapController.move(pos, 15);
                      if (dialogue != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${vendor.name}：$dialogue'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                      _openMinigame();
                    },
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
"""
if marker in s and "void _showBoatSpotPicker()" not in s:
    s = s.replace(marker, insert)

# Refresh active vendor in _refreshBoatSpotState
s = s.replace(
    "    final spots = await BoatVendorService.getActiveSpots();\n    final activeId = await BoatVendorService.getActiveVendorId();",
    "    final spots = await BoatVendorService.getActiveSpots();\n    final activeVendor = await BoatVendorService.getActiveVendor();\n    final activeId = activeVendor?.id;",
)
s = s.replace(
    "          _isAtBoatSpot = false;\n          _cachedBoatSpots = [];",
    "          _isAtBoatSpot = false;\n          _activeBoatVendor = null;\n          _cachedBoatSpots = [];",
)
s = s.replace(
    "        _isAtBoatSpot = atSpot;\n        _cachedBoatSpots = spots;",
    "        _isAtBoatSpot = atSpot;\n        _activeBoatVendor = activeVendor;\n        _cachedBoatSpots = spots;",
)

# Bottom bar onFishNearby: if active vendor, open selector before nearest GPS
old = """            onFishNearby: (_isAtBoatSpot ||
                    (nearestSpot != null && _canOpenSpot(nearestSpot)))
                ? () {
                    final spotToUse =
                        (nearestSpot != null && _canOpenSpot(nearestSpot))
                            ? nearestSpot
                            : (_isAtBoatSpot ? _buildBoatSpotDemo() : null);
                    if (spotToUse != null) {
                      setState(() => _selectedSpot = spotToUse);
                      _openMinigame();
                    }
                  }
                : null,"""
new = """            onFishNearby: (_activeBoatVendor != null ||
                    _isAtBoatSpot ||
                    (nearestSpot != null && _canOpenSpot(nearestSpot)))
                ? () {
                    if (_activeBoatVendor != null) {
                      _showBoatSpotPicker();
                      return;
                    }
                    final spotToUse =
                        (nearestSpot != null && _canOpenSpot(nearestSpot))
                            ? nearestSpot
                            : (_isAtBoatSpot ? _buildBoatSpotDemo() : null);
                    if (spotToUse != null) {
                      setState(() => _selectedSpot = spotToUse);
                      _openMinigame();
                    }
                  }
                : null,"""
s = s.replace(old, new)

# selected detail allows boat spots regardless GPS
s = s.replace(
    "              canStartFishing: selectedCanOpen,\n              onStartFishing: selectedCanOpen ? _openMinigame : null,",
    "              canStartFishing: selectedCanOpen || _selectedSpot!.rarity == 3,\n              onStartFishing: (selectedCanOpen || _selectedSpot!.rarity == 3) ? _openMinigame : null,",
)

# Tutorial no fail: clamp safer and disable fail conditions
old = """      _tension = _tension.clamp(0.0, 100.0);
      _lineMeters = _lineMeters.clamp(0.0, _maxLineMeters);
"""
new = """      if (widget.tutorialMode) {
        _tension = _tension.clamp(0.0, 82.0);
        _lineMeters = _lineMeters.clamp(0.0, _maxLineMeters * 0.88);
      } else {
        _tension = _tension.clamp(0.0, 100.0);
        _lineMeters = _lineMeters.clamp(0.0, _maxLineMeters);
      }
"""
s = s.replace(old, new, 1)
old = """      if (_tension >= 95) {
        _failReason = '張力太高，魚線斷了！';
        _endGame(false);
      } else if (_lineMeters >= _maxLineMeters) {
        _failReason = '線全部放出，魚逃走了！';
        _endGame(false);
      } else if (_fishExhausted && _lineMeters <= 0) {
        _endGame(true);
      }
"""
new = """      if (_fishExhausted && _lineMeters <= 0) {
        _endGame(true);
      } else if (!widget.tutorialMode && _tension >= 95) {
        _failReason = '張力太高，魚線斷了！';
        _endGame(false);
      } else if (!widget.tutorialMode && _lineMeters >= _maxLineMeters) {
        _failReason = '線全部放出，魚逃走了！';
        _endGame(false);
      }
"""
s = s.replace(old, new, 1)

p.write_text(s, encoding='utf-8')
print('patched tutorial safety and boat picker')
