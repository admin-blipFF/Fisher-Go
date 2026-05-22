import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/supabase_config.dart';
import 'core/widgets/app_shell.dart';
import 'features/fish/data/local_fish_species_data_source.dart';
import 'features/fish/data/offline_first_fish_species_repository.dart';
import 'features/fish/data/remote_fish_species_data_source.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Hive.initFlutter();

  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
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
