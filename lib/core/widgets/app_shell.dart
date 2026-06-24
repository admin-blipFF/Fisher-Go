import 'package:flutter/material.dart';

import '../../features/fish/data/fish_species_repository.dart';
import '../../features/game_home/presentation/game_home_screen.dart';
import '../../features/fish/presentation/fish_encyclopedia_screen.dart';
import '../../features/catches/presentation/catch_log_screen.dart';
import '../../features/leaderboard/presentation/leaderboard_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/admin/presentation/admin_screen.dart';
import '../../features/navigation/game_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, this.fishSpeciesRepository});

  final FishSpeciesRepository? fishSpeciesRepository;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  GameScreen _currentScreen = GameScreen.map;
  int _boatPromptNonce = 0;

  void _openScreen(GameScreen screen) =>
      setState(() => _currentScreen = screen);

  void _openBoatFishingFromProfile() {
    setState(() {
      _currentScreen = GameScreen.map;
      _boatPromptNonce++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentScreen.index,
        children: [
          // 0: 地圖首頁
          GameHomeScreen(
            onOpenScreen: _openScreen,
            boatPromptNonce: _boatPromptNonce,
          ),
          // 1: 魚類圖鑑
          _WithMapButton(
            onMapPressed: () => _openScreen(GameScreen.map),
            child: FishEncyclopediaScreen(
              repository: widget.fishSpeciesRepository,
              onOpenMap: () => _openScreen(GameScreen.map),
            ),
          ),
          // 2: 魚獲記錄
          _WithMapButton(
            onMapPressed: () => _openScreen(GameScreen.map),
            child: const CatchLogScreen(),
          ),
          // 3: 排行榜
          _WithMapButton(
            onMapPressed: () => _openScreen(GameScreen.map),
            child: const LeaderboardScreen(),
          ),
          // 4: 角色個人頁
          _WithMapButton(
            onMapPressed: () => _openScreen(GameScreen.map),
            child: ProfileScreen(onBoatRented: _openBoatFishingFromProfile),
          ),
          // 5: 設定（暫以個人頁代替，待商店/設定頁完成）
          _WithMapButton(
            onMapPressed: () => _openScreen(GameScreen.map),
            child: ProfileScreen(onBoatRented: _openBoatFishingFromProfile),
          ),
          // 6: Admin 營運後台
          _WithMapButton(
            onMapPressed: () => _openScreen(GameScreen.map),
            child: const AdminScreen(),
          ),
        ],
      ),
    );
  }
}

/// Wraps any screen with a floating "MAP" button at the bottom-center
/// to quickly return to the game home map.
class _WithMapButton extends StatelessWidget {
  const _WithMapButton({required this.onMapPressed, required this.child});

  final VoidCallback onMapPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        child,
        Positioned(
          left: 0,
          right: 0,
          bottom: 24,
          child: Center(
            child: _GameFloatingMapButton(
              onPressed: onMapPressed,
              colorScheme: colorScheme,
            ),
          ),
        ),
      ],
    );
  }
}

/// Game-styled floating MAP button — prominent, always visible.
class _GameFloatingMapButton extends StatelessWidget {
  const _GameFloatingMapButton({
    required this.onPressed,
    required this.colorScheme,
  });

  final VoidCallback onPressed;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '返回地圖',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(28),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.4),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.map,
                  color: colorScheme.onPrimaryContainer,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  'MAP',
                  style: TextStyle(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: 1.2,
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
