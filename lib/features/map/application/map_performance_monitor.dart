import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

@immutable
class MapFrameSample {
  const MapFrameSample({
    required this.buildDuration,
    required this.rasterDuration,
    required this.totalDuration,
    this.vsyncOverhead = Duration.zero,
    this.frameGap = Duration.zero,
  });

  final Duration buildDuration;
  final Duration rasterDuration;
  final Duration totalDuration;
  final Duration vsyncOverhead;
  final Duration frameGap;
}

Duration frameTimingGap(FrameTiming timing) {
  final gap = timing.totalSpan -
      timing.vsyncOverhead -
      timing.buildDuration -
      timing.rasterDuration;
  return gap.isNegative ? Duration.zero : gap;
}

@immutable
class MapPerformanceSnapshot {
  const MapPerformanceSnapshot({
    required this.frameCount,
    required this.p50BuildFrame,
    required this.p95BuildFrame,
    required this.p50RasterFrame,
    required this.p95RasterFrame,
    required this.p50TotalFrame,
    required this.p95TotalFrame,
    required this.p50VsyncOverhead,
    required this.p95VsyncOverhead,
    required this.p50FrameGap,
    required this.p95FrameGap,
    required this.jankyFrameCount,
    required this.styleReadyAfter,
    required this.mapIdleAfter,
  });

  final int frameCount;
  final Duration p50BuildFrame;
  final Duration p95BuildFrame;
  final Duration p50RasterFrame;
  final Duration p95RasterFrame;
  final Duration p50TotalFrame;
  final Duration p95TotalFrame;
  final Duration p50VsyncOverhead;
  final Duration p95VsyncOverhead;
  final Duration p50FrameGap;
  final Duration p95FrameGap;
  final int jankyFrameCount;
  final Duration? styleReadyAfter;
  final Duration? mapIdleAfter;

  double get jankyFrameRate {
    if (frameCount == 0) return 0;
    return jankyFrameCount / frameCount;
  }

  Map<String, Object?> toJson() {
    return {
      'frame_count': frameCount,
      'p50_build_ms': p50BuildFrame.inMilliseconds,
      'p95_build_ms': p95BuildFrame.inMilliseconds,
      'p50_raster_ms': p50RasterFrame.inMilliseconds,
      'p95_raster_ms': p95RasterFrame.inMilliseconds,
      'p50_total_ms': p50TotalFrame.inMilliseconds,
      'p95_total_ms': p95TotalFrame.inMilliseconds,
      'p50_vsync_overhead_ms': p50VsyncOverhead.inMilliseconds,
      'p95_vsync_overhead_ms': p95VsyncOverhead.inMilliseconds,
      'p50_frame_gap_ms': p50FrameGap.inMilliseconds,
      'p95_frame_gap_ms': p95FrameGap.inMilliseconds,
      'janky_frames': jankyFrameCount,
      'janky_rate': jankyFrameRate,
      'style_ready_ms': styleReadyAfter?.inMilliseconds,
      'map_idle_ms': mapIdleAfter?.inMilliseconds,
    };
  }
}

/// Keeps a bounded sample window for comparing map rendering costs.
///
/// The monitor is deliberately independent from MapLibre and Flutter widgets
/// so the same calculations can be used by Web and Android measurements.
class MapPerformanceMonitor {
  MapPerformanceMonitor({
    this.frameBudget = const Duration(milliseconds: 20),
    this.maxSamples = 240,
  }) : assert(maxSamples > 0);

  final Duration frameBudget;
  final int maxSamples;
  final List<MapFrameSample> _samples = <MapFrameSample>[];
  DateTime? _startedAt;
  Duration? _styleReadyAfter;
  Duration? _mapIdleAfter;

  void markStarted({DateTime? at}) {
    _startedAt = at ?? DateTime.now();
  }

  void markStyleReady({DateTime? at}) {
    final startedAt = _startedAt;
    if (startedAt == null || _styleReadyAfter != null) return;

    final elapsed = (at ?? DateTime.now()).difference(startedAt);
    _styleReadyAfter = elapsed.isNegative ? Duration.zero : elapsed;
  }

  void markMapIdle({DateTime? at}) {
    final startedAt = _startedAt;
    if (startedAt == null || _mapIdleAfter != null) return;

    final elapsed = (at ?? DateTime.now()).difference(startedAt);
    _mapIdleAfter = elapsed.isNegative ? Duration.zero : elapsed;
  }

  void recordFrame(MapFrameSample sample) {
    if (_samples.length >= maxSamples) {
      _samples.removeAt(0);
    }
    _samples.add(sample);
  }

  MapPerformanceSnapshot snapshot() {
    final buildDurations =
        _samples.map((sample) => sample.buildDuration).toList(growable: false);
    final rasterDurations =
        _samples.map((sample) => sample.rasterDuration).toList(growable: false);
    final totalDurations =
        _samples.map((sample) => sample.totalDuration).toList(growable: false);
    final vsyncOverheads =
        _samples.map((sample) => sample.vsyncOverhead).toList(growable: false);
    final frameGaps =
        _samples.map((sample) => sample.frameGap).toList(growable: false);

    return MapPerformanceSnapshot(
      frameCount: _samples.length,
      p50BuildFrame: _percentile(buildDurations, 0.50),
      p95BuildFrame: _percentile(buildDurations, 0.95),
      p50RasterFrame: _percentile(rasterDurations, 0.50),
      p95RasterFrame: _percentile(rasterDurations, 0.95),
      p50TotalFrame: _percentile(totalDurations, 0.50),
      p95TotalFrame: _percentile(totalDurations, 0.95),
      p50VsyncOverhead: _percentile(vsyncOverheads, 0.50),
      p95VsyncOverhead: _percentile(vsyncOverheads, 0.95),
      p50FrameGap: _percentile(frameGaps, 0.50),
      p95FrameGap: _percentile(frameGaps, 0.95),
      jankyFrameCount:
          _samples.where((sample) => sample.totalDuration > frameBudget).length,
      styleReadyAfter: _styleReadyAfter,
      mapIdleAfter: _mapIdleAfter,
    );
  }

  Duration _percentile(List<Duration> values, double percentile) {
    if (values.isEmpty) return Duration.zero;
    final sorted = values.toList()..sort();
    final index = ((sorted.length - 1) * percentile).round();
    return sorted[index];
  }
}

/// Emits one measurement log when each fixed-size frame bucket is crossed.
///
/// Timings callbacks can deliver a batch that jumps over an exact boundary,
/// so callers must not wait for a frame count to equal 60, 120, and so on.
class MapPerformanceReporter {
  MapPerformanceReporter({this.reportEvery = 60}) : assert(reportEvery > 0);

  final int reportEvery;
  int _lastReportedBucket = 0;

  bool shouldReport(int frameCount) {
    if (frameCount < reportEvery) return false;

    final bucket = frameCount ~/ reportEvery;
    if (bucket <= _lastReportedBucket) return false;

    _lastReportedBucket = bucket;
    return true;
  }
}
