import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 地圖雷達網格繪製器 — 疊加在 FlutterMap 上方
class RadarGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius =
        math.sqrt(size.width * size.width + size.height * size.height) / 2;
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.cyanAccent.withValues(alpha: 0.18);
    final beamPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.lightGreenAccent.withValues(alpha: 0.12);

    for (var i = 1; i <= 4; i++) {
      canvas.drawCircle(center, maxRadius * i / 4, ringPaint);
    }
    for (var angle = 0; angle < 360; angle += 45) {
      final radians = angle * math.pi / 180;
      final end = Offset(
        center.dx + math.cos(radians) * maxRadius,
        center.dy + math.sin(radians) * maxRadius,
      );
      canvas.drawLine(center, end, beamPaint);
    }

    final sweepPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          Colors.transparent,
          Colors.cyanAccent.withValues(alpha: 0.16),
          Colors.transparent,
        ],
        stops: const [0.0, 0.08, 0.18],
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius));
    canvas.drawCircle(center, maxRadius, sweepPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
