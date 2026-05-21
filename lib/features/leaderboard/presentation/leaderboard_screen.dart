import 'package:flutter/material.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: AppBar(title: Text('每日排行榜')),
      body: Center(child: Text('Phase 5: 即時排行榜')),
    );
  }
}
