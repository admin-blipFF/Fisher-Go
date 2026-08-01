import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('operations boundaries emit structured telemetry events', () {
    final sources = [
      File('lib/main.dart').readAsStringSync(),
      File('lib/features/map/presentation/game_map_libre.dart')
          .readAsStringSync(),
      File('lib/features/catches/data/catch_sync_service.dart')
          .readAsStringSync(),
      File('lib/features/catches/presentation/catch_log_screen.dart')
          .readAsStringSync(),
      File('lib/features/game_home/presentation/game_home_screen.dart')
          .readAsStringSync(),
      File('lib/features/profile/data/profile_wallet_service.dart')
          .readAsStringSync(),
      File('lib/core/telemetry/app_telemetry.dart').readAsStringSync(),
      File('lib/core/telemetry/supabase_analytics_sink.dart')
          .readAsStringSync(),
      File('lib/core/config/public_app_config.dart').readAsStringSync(),
    ];
    final source = sources.join('\n');

    expect(source, contains('AppTelemetry.instance.record'));
    expect(source, contains('TelemetryEventName.appBootstrap'));
    expect(source, contains('TelemetryEventName.appError'));
    expect(source, contains('TelemetryEventName.authIdentitySelected'));
    expect(source, contains('TelemetryEventName.mapReady'));
    expect(source, contains('TelemetryEventName.mapIdle'));
    expect(source, contains('TelemetryEventName.minigameStarted'));
    expect(source, contains('TelemetryEventName.minigameCompleted'));
    expect(source, contains('TelemetryEventName.catchUpload'));
    expect(source, contains('TelemetryEventName.catchSync'));
    expect(source, contains("'durationMs'"));
    expect(source, contains('TelemetryEventName.rewardClaimed'));
    expect(source, contains('FISHERGO_RELEASE_ID'));
    expect(source, contains('FISHERGO_ENVIRONMENT'));
    expect(source, contains('environment'));
    expect(source, contains('configureSink'));
    expect(source, contains('record_analytics_event'));
    expect(source, contains('FISHERGO_ANALYTICS_ENABLED'));
  });
}
