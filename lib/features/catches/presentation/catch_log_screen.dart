import 'package:flutter/material.dart';

class CatchLogScreen extends StatelessWidget {
  const CatchLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: AppBar(title: Text('魚獲記錄')),
      body: Center(child: Text('Phase 4: 手動魚獲記錄')),
    );
  }
}
