import 'package:flutter/material.dart';

class CatchLogScreen extends StatelessWidget {
  const CatchLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('魚獲記錄')),
      body: const Center(child: Text('Phase 4: 手動魚獲記錄')),
    );
  }
}
