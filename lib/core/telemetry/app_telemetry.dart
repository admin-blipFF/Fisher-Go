import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

enum TelemetryEventName {
  appBootstrap('app_bootstrap'),
  appError('app_error'),
  authIdentitySelected('auth_identity_selected'),
  mapReady('map_ready'),
  mapIdle('map_idle'),
  mapFallback('map_fallback'),
  minigameStarted('minigame_started'),
  minigameCompleted('minigame_completed'),
  catchUpload('catch_upload'),
  catchSync('catch_sync'),
  rewardClaimed('reward_claimed');

  const TelemetryEventName(this.value);

  final String value;
}

class TelemetryEvent {
  const TelemetryEvent({
    required this.name,
    required this.occurredAt,
    required this.buildTime,
    required this.releaseId,
    required this.environment,
    required this.fields,
  });

  final String name;
  final DateTime occurredAt;
  final String buildTime;
  final String releaseId;
  final String environment;
  final Map<String, Object?> fields;

  Map<String, Object?> toMap() => {
        'name': name,
        'occurredAt': occurredAt.toIso8601String(),
        'buildTime': buildTime,
        'releaseId': releaseId,
        'environment': environment,
        'fields': fields,
      };
}

typedef TelemetrySink = FutureOr<void> Function(TelemetryEvent event);

class AppTelemetry {
  AppTelemetry({
    TelemetrySink? sink,
    DateTime Function()? clock,
    int maxBufferSize = 100,
  }) : this._internal(
          sink: sink,
          clock: clock,
          maxBufferSize: maxBufferSize,
        );

  AppTelemetry._internal({
    TelemetrySink? sink,
    this.clock,
    this.maxBufferSize = 100,
  })  : _sink = sink,
        assert(maxBufferSize > 0);

  static final AppTelemetry instance = AppTelemetry._internal();

  TelemetrySink? _sink;
  final DateTime Function()? clock;
  final int maxBufferSize;
  final ListQueue<TelemetryEvent> _buffer = ListQueue<TelemetryEvent>();

  TelemetrySink? get sink => _sink;

  List<TelemetryEvent> get bufferedEvents =>
      List<TelemetryEvent>.unmodifiable(_buffer);

  Future<void> record(
    TelemetryEventName eventName, {
    Map<String, Object?> fields = const <String, Object?>{},
  }) async {
    final event = TelemetryEvent(
      name: eventName.value,
      occurredAt: (clock ?? DateTime.now).call().toUtc(),
      buildTime:
          const String.fromEnvironment('BUILD_TIME', defaultValue: 'dev'),
      releaseId: const String.fromEnvironment(
        'FISHERGO_RELEASE_ID',
        defaultValue: 'dev',
      ),
      environment: const String.fromEnvironment(
        'FISHERGO_ENVIRONMENT',
        defaultValue: kReleaseMode ? 'production' : 'development',
      ),
      fields: _sanitizeFields(fields),
    );
    _buffer.addLast(event);
    while (_buffer.length > maxBufferSize) {
      _buffer.removeFirst();
    }

    await _deliver(event, _sink);
  }

  /// Installs the optional remote sink after Supabase has initialized.
  ///
  /// Events buffered during bootstrap are replayed once so the install and
  /// cold-start funnel is not lost behind asynchronous service setup.
  void configureSink(TelemetrySink? nextSink) {
    if (identical(_sink, nextSink)) return;
    _sink = nextSink;
    if (nextSink == null) return;
    for (final event in _buffer) {
      unawaited(_deliver(event, nextSink));
    }
  }

  Future<void> _deliver(TelemetryEvent event, TelemetrySink? target) async {
    try {
      await target?.call(event);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('FisherGO telemetry sink error (non-fatal): $error');
      }
    }
  }

  static Map<String, Object?> _sanitizeFields(Map<String, Object?> fields) {
    final sanitized = <String, Object?>{};
    for (final entry in fields.entries) {
      final key = entry.key.toLowerCase();
      if (_isSensitiveKey(key)) continue;
      final value = entry.value;
      if (value == null || value is String || value is num || value is bool) {
        sanitized[entry.key] = value;
      }
    }
    return Map<String, Object?>.unmodifiable(sanitized);
  }

  static bool _isSensitiveKey(String key) =>
      key.contains('user') ||
      key.contains('email') ||
      key.contains('token') ||
      key.contains('password') ||
      key.contains('error_message') ||
      key.contains('exception') ||
      key.contains('stack_trace') ||
      key.contains('latitude') ||
      key.contains('longitude') ||
      key.contains('photo') ||
      key.contains('path') ||
      key.contains('note');
}
