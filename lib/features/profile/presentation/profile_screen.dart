import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: AppBar(title: Text('個人資料')),
      body: Center(child: Text('Supabase Auth profile placeholder')),
    );
  }
}
