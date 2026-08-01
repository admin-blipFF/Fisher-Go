import 'package:flutter_test/flutter_test.dart';

import 'package:fishergo/core/telemetry/app_telemetry.dart';

void main() {
  test('telemetry keeps event names and removes sensitive fields', () async {
    final captured = <TelemetryEvent>[];
    final telemetry = AppTelemetry(
      clock: () => DateTime.utc(2026, 7, 31, 2),
      sink: captured.add,
    );

    await telemetry.record(
      TelemetryEventName.catchSync,
      fields: {
        'synced': 2,
        'outcome': 'success',
        'userId': 'user-secret',
        'email': 'player@example.com',
        'latitude': 22.3,
        'longitude': 114.1,
        'photoPath': '/private/photo.jpg',
        'accessToken': 'token-secret',
      },
    );

    expect(captured, hasLength(1));
    expect(captured.single.name, TelemetryEventName.catchSync.value);
    expect(captured.single.buildTime, isNotEmpty);
    expect(captured.single.fields, {'synced': 2, 'outcome': 'success'});
  });

  test('telemetry sink failures are swallowed', () async {
    final telemetry = AppTelemetry(
      sink: (_) => throw StateError('telemetry unavailable'),
    );

    await expectLater(
      telemetry.record(TelemetryEventName.mapReady),
      completes,
    );
  });

  test('telemetry preserves privacy-safe duration metrics', () async {
    final telemetry = AppTelemetry();

    await telemetry.record(
      TelemetryEventName.mapIdle,
      fields: {'durationMs': 1320},
    );

    expect(telemetry.bufferedEvents.single.name, 'map_idle');
    expect(telemetry.bufferedEvents.single.fields['durationMs'], 1320);
  });

  test('telemetry event buffer is bounded', () async {
    final telemetry = AppTelemetry(maxBufferSize: 2);

    await telemetry.record(TelemetryEventName.appBootstrap);
    await telemetry.record(TelemetryEventName.authIdentitySelected);
    await telemetry.record(TelemetryEventName.rewardClaimed);

    expect(telemetry.bufferedEvents, hasLength(2));
    expect(
      telemetry.bufferedEvents.map((event) => event.name),
      [
        TelemetryEventName.authIdentitySelected.value,
        TelemetryEventName.rewardClaimed.value,
      ],
    );
  });

  test('telemetry serializes release provenance', () async {
    final telemetry = AppTelemetry(
      clock: () => DateTime.utc(2026, 7, 31, 2),
    );

    await telemetry.record(TelemetryEventName.appBootstrap);

    final event = telemetry.bufferedEvents.single;
    expect(event.releaseId, isNotEmpty);
    expect(event.environment, isNotEmpty);
    expect(event.toMap(), containsPair('releaseId', event.releaseId));
    expect(event.toMap(), containsPair('environment', event.environment));
  });

  test('configuring a remote sink replays buffered bootstrap telemetry',
      () async {
    final captured = <TelemetryEvent>[];
    final telemetry = AppTelemetry();

    await telemetry.record(TelemetryEventName.appBootstrap);
    telemetry.configureSink(captured.add);
    await Future<void>.delayed(Duration.zero);
    await telemetry.record(TelemetryEventName.mapReady);

    expect(captured.map((event) => event.name), [
      TelemetryEventName.appBootstrap.value,
      TelemetryEventName.mapReady.value,
    ]);
  });

  test('app errors keep only privacy-safe diagnostic fields', () async {
    final telemetry = AppTelemetry(
      sink: (_) {},
    );

    await telemetry.record(
      TelemetryEventName.appError,
      fields: {
        'source': 'platform',
        'fatal': true,
        'error_type': 'StateError',
        'error_message': 'private account data',
        'stack_trace': 'private stack trace',
        'latitude': 22.3,
      },
    );

    expect(telemetry.bufferedEvents.single.fields, {
      'source': 'platform',
      'fatal': true,
      'error_type': 'StateError',
    });
  });
}
