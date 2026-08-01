import 'package:fishergo/features/map/application/map_performance_monitor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps a bounded frame window and calculates p95 and jank rate', () {
    final monitor = MapPerformanceMonitor(
      frameBudget: const Duration(milliseconds: 20),
      maxSamples: 3,
    );

    monitor.recordFrame(const MapFrameSample(
      buildDuration: Duration(milliseconds: 4),
      rasterDuration: Duration(milliseconds: 5),
      totalDuration: Duration(milliseconds: 10),
    ));
    monitor.recordFrame(const MapFrameSample(
      buildDuration: Duration(milliseconds: 10),
      rasterDuration: Duration(milliseconds: 12),
      totalDuration: Duration(milliseconds: 30),
    ));
    monitor.recordFrame(const MapFrameSample(
      buildDuration: Duration(milliseconds: 12),
      rasterDuration: Duration(milliseconds: 18),
      totalDuration: Duration(milliseconds: 50),
    ));
    monitor.recordFrame(const MapFrameSample(
      buildDuration: Duration(milliseconds: 16),
      rasterDuration: Duration(milliseconds: 25),
      totalDuration: Duration(milliseconds: 70),
    ));

    final snapshot = monitor.snapshot();

    expect(snapshot.frameCount, 3);
    expect(snapshot.p50TotalFrame, const Duration(milliseconds: 50));
    expect(snapshot.p95TotalFrame, const Duration(milliseconds: 70));
    expect(snapshot.p95BuildFrame, const Duration(milliseconds: 16));
    expect(snapshot.p95RasterFrame, const Duration(milliseconds: 25));
    expect(snapshot.jankyFrameCount, 3);
    expect(snapshot.jankyFrameRate, closeTo(1, 0.001));
  });

  test('records style readiness from an injected clock and serializes metrics',
      () {
    final started = DateTime(2026, 7, 18, 12, 0, 0);
    final monitor = MapPerformanceMonitor()..markStarted(at: started);

    monitor.markStyleReady(at: started.add(const Duration(milliseconds: 840)));
    monitor.markMapIdle(at: started.add(const Duration(milliseconds: 1320)));
    monitor.markMapIdle(at: started.add(const Duration(milliseconds: 2400)));
    monitor.recordFrame(const MapFrameSample(
      buildDuration: Duration(milliseconds: 5),
      rasterDuration: Duration(milliseconds: 7),
      totalDuration: Duration(milliseconds: 14),
    ));

    final snapshot = monitor.snapshot();

    expect(snapshot.styleReadyAfter, const Duration(milliseconds: 840));
    expect(snapshot.mapIdleAfter, const Duration(milliseconds: 1320));
    expect(snapshot.toJson(), containsPair('frame_count', 1));
    expect(snapshot.toJson(), containsPair('style_ready_ms', 840));
    expect(snapshot.toJson(), containsPair('map_idle_ms', 1320));
    expect(snapshot.toJson(), containsPair('p95_total_ms', 14));
  });

  test('empty monitor reports no false readiness or jank', () {
    final snapshot = MapPerformanceMonitor().snapshot();

    expect(snapshot.frameCount, 0);
    expect(snapshot.p95TotalFrame, Duration.zero);
    expect(snapshot.styleReadyAfter, isNull);
    expect(snapshot.mapIdleAfter, isNull);
    expect(snapshot.jankyFrameRate, 0);
  });

  test('tracks vsync overhead separately from build and raster work', () {
    final monitor = MapPerformanceMonitor();

    monitor.recordFrame(const MapFrameSample(
      buildDuration: Duration(milliseconds: 4),
      rasterDuration: Duration(milliseconds: 6),
      totalDuration: Duration(milliseconds: 38),
      vsyncOverhead: Duration(milliseconds: 28),
      frameGap: Duration.zero,
    ));
    monitor.recordFrame(const MapFrameSample(
      buildDuration: Duration(milliseconds: 5),
      rasterDuration: Duration(milliseconds: 7),
      totalDuration: Duration(milliseconds: 16),
      vsyncOverhead: Duration(milliseconds: 2),
      frameGap: Duration(milliseconds: 2),
    ));

    final snapshot = monitor.snapshot();

    expect(snapshot.p95VsyncOverhead, const Duration(milliseconds: 28));
    expect(snapshot.toJson(), containsPair('p95_vsync_overhead_ms', 28));
    expect(snapshot.p95FrameGap, const Duration(milliseconds: 2));
    expect(snapshot.toJson(), containsPair('p95_frame_gap_ms', 2));
  });

  test('performance reporter emits once when a frame bucket is crossed', () {
    final reporter = MapPerformanceReporter(reportEvery: 60);

    expect(reporter.shouldReport(59), isFalse);
    expect(reporter.shouldReport(64), isTrue);
    expect(reporter.shouldReport(65), isFalse);
    expect(reporter.shouldReport(120), isTrue);
    expect(reporter.shouldReport(121), isFalse);
  });
}
