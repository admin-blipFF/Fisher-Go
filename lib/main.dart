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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // Keep app bootable in deployments where .env is intentionally absent.
  }
  await Hive.initFlutter();

  if (SupabaseConfig.isConfigured) {
    debugPrint('DEBUG: Supabase configured, URL=${SupabaseConfig.url}');
    // Clear any stale Supabase session (e.g. old anonymous sessions)
    // to prevent "anonymous signs in are disabled" errors on web.
    clearStaleSupabaseSession();

    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        anonKey: SupabaseConfig.anonKey,
      );

      // Auto sign-in anonymously so catches sync without forcing account
      // creation. Existing sessions (anonymous or email) are preserved.
      final auth = Supabase.instance.client.auth;
      if (auth.currentUser == null) {
        try {
          await auth.signInAnonymously();
          debugPrint('DEBUG: signed in anonymously');
        } catch (e) {
          debugPrint('Anonymous sign-in failed (non-fatal): $e');
        }
      }
    } catch (e) {
      debugPrint('Supabase init error (non-fatal): $e');
    }
  } else {
    debugPrint('DEBUG: Supabase NOT configured — check .env');
  }

  runApp(const FisherGoApp());
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
