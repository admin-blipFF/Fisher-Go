import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/supabase_config.dart';
import 'core/web_session_clear.dart';
import 'core/widgets/app_shell.dart';
import 'features/fish/data/local_fish_species_data_source.dart';
import 'features/fish/data/offline_first_fish_species_repository.dart';
import 'features/fish/data/remote_fish_species_data_source.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FisherGoBootstrap());
}

class FisherGoBootstrap extends StatefulWidget {
  const FisherGoBootstrap({super.key});

  @override
  State<FisherGoBootstrap> createState() => _FisherGoBootstrapState();
}

class _FisherGoBootstrapState extends State<FisherGoBootstrap> {
  final Completer<void> _initialization = Completer<void>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await _initializeServices();
      } finally {
        if (!_initialization.isCompleted) _initialization.complete();
      }
    });
  }

  Future<void> _initializeServices() async {
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      // Keep app bootable in deployments where .env is intentionally absent.
    }
    await Hive.initFlutter();

    if (!SupabaseConfig.isConfigured) {
      debugPrint('DEBUG: Supabase NOT configured - check .env');
      return;
    }

    debugPrint('DEBUG: Supabase configured, URL=${SupabaseConfig.url}');
    clearStaleSupabaseSession();
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        anonKey: SupabaseConfig.anonKey,
      );
      unawaited(_signInAnonymouslyIfNeeded());
    } catch (error) {
      debugPrint('Supabase init error (non-fatal): $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initialization.future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return const FisherGoApp();
        }
        return const MaterialApp(home: _FisherGoLoadingScreen());
      },
    );
  }
}

class _FisherGoLoadingScreen extends StatelessWidget {
  const _FisherGoLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF062F38),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sailing, color: Color(0xFF7DF9FF), size: 54),
              SizedBox(height: 18),
              Text(
                'FisherGO 正在準備海圖',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 18),
              SizedBox(
                width: 128,
                child: LinearProgressIndicator(
                  minHeight: 3,
                  color: Color(0xFF7DF9FF),
                  backgroundColor: Color(0xFF164E58),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _signInAnonymouslyIfNeeded() async {
  final auth = Supabase.instance.client.auth;
  if (auth.currentUser != null) return;
  try {
    await auth.signInAnonymously();
    debugPrint('DEBUG: signed in anonymously');
  } catch (error) {
    debugPrint('Anonymous sign-in failed (non-fatal): $error');
  }
}

class FisherGoApp extends StatelessWidget {
  const FisherGoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FisherGO',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: AppShell(fishSpeciesRepository: _buildFishRepository()),
    );
  }

  OfflineFirstFishSpeciesRepository? _buildFishRepository() {
    if (!SupabaseConfig.isConfigured) return null;

    return OfflineFirstFishSpeciesRepository(
      remote: RemoteFishSpeciesDataSource(Supabase.instance.client),
      local: LocalFishSpeciesDataSource(),
    );
  }
}
