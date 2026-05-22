import 'package:flutter/material.dart';

import '../../features/fish/data/fish_species_repository.dart';
import '../../features/catches/presentation/catch_log_screen.dart';
import '../../features/fish/presentation/fish_encyclopedia_screen.dart';
import '../../features/leaderboard/presentation/leaderboard_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, this.fishSpeciesRepository});

  final FishSpeciesRepository? fishSpeciesRepository;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      FishEncyclopediaScreen(repository: widget.fishSpeciesRepository),
      const CatchLogScreen(),
      const LeaderboardScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: screens[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.menu_book), label: '圖鑑'),
          NavigationDestination(icon: Icon(Icons.camera_alt), label: '魚獲'),
          NavigationDestination(icon: Icon(Icons.emoji_events), label: '排行'),
          NavigationDestination(icon: Icon(Icons.person), label: '個人'),
        ],
      ),
    );
  }
}
