import 'package:flutter/material.dart';

class FishEncyclopediaScreen extends StatelessWidget {
  const FishEncyclopediaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: AppBar(title: Text('香港魚類圖鑑')),
      body: Center(
        child: Text('Phase 3: 離線優先圖鑑將在此顯示'),
      ),
    );
  }
}
