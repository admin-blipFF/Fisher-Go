import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/public_app_config.dart';
import 'app_telemetry.dart';

/// Bounded, delayed delivery for the privacy-filtered telemetry contract.
///
/// The sink intentionally drops a failed batch. Analytics must never block
/// startup, gameplay, or account flows, and the AppTelemetry buffer remains
/// the local diagnostic fallback.
class SupabaseAnalyticsSink {
  SupabaseAnalyticsSink({
    SupabaseClient? client,
    Duration flushDelay = const Duration(seconds: 3),
    int batchSize = 8,
  })  : _client = client,
        _flushDelay = flushDelay,
        _batchSize = batchSize,
        assert(batchSize > 0);

  final SupabaseClient? _client;
  final Duration _flushDelay;
  final int _batchSize;
  final List<TelemetryEvent> _pending = <TelemetryEvent>[];
  Timer? _timer;
  bool _flushing = false;

  int get pendingCount => _pending.length;

  SupabaseClient? get _resolvedClient {
    if (_client != null) return _client;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  Future<void> call(TelemetryEvent event) async {
    if (!PublicAppConfig.analyticsEnabled) return;
    _pending.add(event);
    if (_pending.length >= _batchSize) {
      unawaited(flushNow());
      return;
    }
    _timer ??= Timer(_flushDelay, () {
      _timer = null;
      unawaited(flushNow());
    });
  }

  Future<void> flushNow() async {
    if (_flushing || _pending.isEmpty) return;
    _flushing = true;
    _timer?.cancel();
    _timer = null;
    final count = _pending.length < _batchSize ? _pending.length : _batchSize;
    final batch = _pending.sublist(0, count);
    _pending.removeRange(0, count);

    try {
      final client = _resolvedClient;
      if (client == null) return;
      for (final event in batch) {
        await client.rpc(
          'record_analytics_event',
          params: <String, Object?>{
            'p_event_name': event.name,
            'p_occurred_at': event.occurredAt.toIso8601String(),
            'p_build_time': event.buildTime,
            'p_release_id': event.releaseId,
            'p_environment': event.environment,
            'p_fields': event.fields,
          },
        );
      }
    } catch (_) {
      // Analytics is best effort; do not retry a possibly invalid payload.
    } finally {
      _flushing = false;
      if (_pending.isNotEmpty) {
        _timer ??= Timer(_flushDelay, () {
          _timer = null;
          unawaited(flushNow());
        });
      }
    }
  }
}
