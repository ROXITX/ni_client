import 'package:flutter/material.dart';
import 'dart:math' as math;

class DashboardSpeedometerPainter extends CustomPainter {
  final double ratio;

  DashboardSpeedometerPainter({required this.ratio});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width * 0.4;

    final basePaint = Paint()
      ..color = const Color(0xFFEF4444)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 8;
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(rect, math.pi, math.pi, false, basePaint);

    final greenPaint = Paint()
      ..color = const Color(0xFF22C55E)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 8;
    final clamped = ratio.clamp(0.0, 1.0);
    final sweep = (math.pi) * clamped;
    canvas.drawArc(rect, math.pi, sweep, false, greenPaint);

    final needlePaint = Paint()
      ..color = const Color(0xFF1F2937)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final angle = math.pi * (1 - clamped);
    final needleLen = radius * 0.85;
    final tip = Offset(
      center.dx + needleLen * math.cos(angle),
      center.dy - needleLen * math.sin(angle),
    );
    canvas.drawLine(center, tip, needlePaint);
    final hubPaint = Paint()
      ..color = const Color(0xFF1F2937);
    canvas.drawCircle(center, 4, hubPaint);

    final labelY = center.dy - 12;
    final tp0 = _tp('0', const Color(0xFF9CA3AF));
    tp0.paint(canvas, Offset(center.dx - radius + 2, labelY));
    final tpAll = _tp('All', const Color(0xFF9CA3AF));
    tpAll.paint(canvas, Offset(center.dx + radius - 22, labelY));
  }

  TextPainter _tp(String text, Color color) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: 10)),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    return tp;
  }

  @override
  bool shouldRepaint(covariant DashboardSpeedometerPainter oldDelegate) => oldDelegate.ratio != ratio;
}
