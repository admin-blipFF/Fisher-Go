import 'dart:async';

import 'package:flutter/material.dart';

import '../update/update_prompt_overlay.dart';
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
  final Set<int> _builtScreens = <int>{GameScreen.map.index};
  final List<Widget?> _screenWidgets =
      List<Widget?>.filled(GameScreen.values.length, null);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(checkForAppUpdate(context));
    });
  }

  void _openScreen(GameScreen screen) {
    setState(() {
      _currentScreen = screen;
      _builtScreens.add(screen.index);
    });
  }

  void _openBoatFishingFromProfile() {
    final nextBoatPromptNonce = _boatPromptNonce + 1;
    setState(() {
      _currentScreen = GameScreen.map;
      _builtScreens.add(GameScreen.map.index);
      _boatPromptNonce = nextBoatPromptNonce;
      _screenWidgets[GameScreen.map.index] = GameHomeScreen(
        onOpenScreen: _openScreen,
        boatPromptNonce: nextBoatPromptNonce,
      );
    });
  }

  Widget _createScreen(GameScreen screen) {
    switch (screen) {
      case GameScreen.map:
        return GameHomeScreen(
          onOpenScreen: _openScreen,
          boatPromptNonce: _boatPromptNonce,
        );
      case GameScreen.encyclopedia:
        return _WithMapButton(
          onMapPressed: () => _openScreen(GameScreen.map),
          child: FishEncyclopediaScreen(
            repository: widget.fishSpeciesRepository,
            onOpenMap: () => _openScreen(GameScreen.map),
          ),
        );
      case GameScreen.catchLog:
        return _WithMapButton(
          onMapPressed: () => _openScreen(GameScreen.map),
          child: const CatchLogScreen(),
        );
      case GameScreen.leaderboard:
        return _WithMapButton(
          onMapPressed: () => _openScreen(GameScreen.map),
          child: const LeaderboardScreen(),
        );
      case GameScreen.profile:
        return _WithMapButton(
          onMapPressed: () => _openScreen(GameScreen.map),
          child: ProfileScreen(onBoatRented: _openBoatFishingFromProfile),
        );
      case GameScreen.settings:
        return _WithMapButton(
          onMapPressed: () => _openScreen(GameScreen.map),
          child: ProfileScreen(onBoatRented: _openBoatFishingFromProfile),
        );
      case GameScreen.admin:
        return _WithMapButton(
          onMapPressed: () => _openScreen(GameScreen.map),
          child: const AdminScreen(),
        );
    }
  }

  Widget _screenSlot(GameScreen screen) {
    if (!_builtScreens.contains(screen.index)) return const SizedBox.shrink();
    final child = _screenWidgets[screen.index] ??= _createScreen(screen);
    return Offstage(
      offstage: _currentScreen != screen,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentScreen.index,
        children: [for (final screen in GameScreen.values) _screenSlot(screen)],
      ),
    );
  }
}

/// Wraps secondary screens with a reserved bottom navigation area so the map
/// action never covers scrollable content.
class _WithMapButton extends StatelessWidget {
  const _WithMapButton({required this.onMapPressed, required this.child});

  final VoidCallback onMapPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Expanded(child: child),
        SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Align(
            alignment: Alignment.center,
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

/// Compact game-styled map navigation control.
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
      key: const ValueKey('return-map-control'),
      button: true,
      label: '返回地圖',
      child: IconButton.filled(
        tooltip: '返回地圖',
        onPressed: onPressed,
        icon: const Icon(Icons.map_outlined),
        style: IconButton.styleFrom(
          backgroundColor: colorScheme.primaryContainer,
          foregroundColor: colorScheme.onPrimaryContainer,
          fixedSize: const Size(52, 52),
          elevation: 4,
          shadowColor: colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}
