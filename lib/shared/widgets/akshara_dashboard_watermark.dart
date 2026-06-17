import 'dart:math' as math;

import 'package:flutter/material.dart';

/// M15.5 decorative watermark motifs (3–8% opacity).
enum AksharaWatermarkMotif {
  graduationCap,
  bookStack,
  busRoute,
  chartTrend,
  shield,
  sparkles,
}

/// Large faint watermark overlay for dashboard canvases.
class AksharaDashboardWatermark extends StatelessWidget {
  const AksharaDashboardWatermark({
    super.key,
    required this.motif,
    this.opacity = 0.05,
    this.alignment = Alignment.centerRight,
    this.size = 220,
  });

  final AksharaWatermarkMotif motif;
  final double opacity;
  final Alignment alignment;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface.withValues(
          alpha: opacity.clamp(0.03, 0.08),
        );

    return IgnorePointer(
      child: Align(
        alignment: alignment,
        child: Padding(
          padding: const EdgeInsets.only(right: 8, top: 24),
          child: CustomPaint(
            size: Size(size, size),
            painter: _WatermarkPainter(motif: motif, color: color),
          ),
        ),
      ),
    );
  }
}

class _WatermarkPainter extends CustomPainter {
  _WatermarkPainter({required this.motif, required this.color});

  final AksharaWatermarkMotif motif;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.018
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (motif) {
      case AksharaWatermarkMotif.graduationCap:
        _drawGraduationCap(canvas, size, paint);
      case AksharaWatermarkMotif.bookStack:
        _drawBookStack(canvas, size, paint);
      case AksharaWatermarkMotif.busRoute:
        _drawBusRoute(canvas, size, paint);
      case AksharaWatermarkMotif.chartTrend:
        _drawChartTrend(canvas, size, paint);
      case AksharaWatermarkMotif.shield:
        _drawShield(canvas, size, paint);
      case AksharaWatermarkMotif.sparkles:
        _drawSparkles(canvas, size, paint);
    }
  }

  void _drawGraduationCap(Canvas canvas, Size size, Paint paint) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.1, h * 0.42)
      ..lineTo(w * 0.5, h * 0.22)
      ..lineTo(w * 0.9, h * 0.42)
      ..lineTo(w * 0.5, h * 0.62)
      ..close();
    canvas.drawPath(path, paint);
    canvas.drawLine(
      Offset(w * 0.5, h * 0.22),
      Offset(w * 0.5, h * 0.08),
      paint,
    );
    canvas.drawRect(
      Rect.fromLTWH(w * 0.28, h * 0.58, w * 0.44, h * 0.12),
      paint,
    );
  }

  void _drawBookStack(Canvas canvas, Size size, Paint paint) {
    for (var i = 0; i < 3; i++) {
      final top = size.height * (0.35 + i * 0.12);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(size.width * 0.22, top, size.width * 0.56, size.height * 0.14),
          const Radius.circular(4),
        ),
        paint,
      );
    }
  }

  void _drawBusRoute(Canvas canvas, Size size, Paint paint) {
    final path = Path()
      ..moveTo(size.width * 0.15, size.height * 0.7)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.2,
        size.width * 0.85,
        size.height * 0.55,
      );
    canvas.drawPath(path, paint);
    canvas.drawCircle(Offset(size.width * 0.15, size.height * 0.7), 6, paint);
    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.55), 6, paint);
  }

  void _drawChartTrend(Canvas canvas, Size size, Paint paint) {
    final path = Path()
      ..moveTo(size.width * 0.15, size.height * 0.72)
      ..lineTo(size.width * 0.35, size.height * 0.55)
      ..lineTo(size.width * 0.55, size.height * 0.62)
      ..lineTo(size.width * 0.85, size.height * 0.28);
    canvas.drawPath(path, paint);
  }

  void _drawShield(Canvas canvas, Size size, Paint paint) {
    final path = Path()
      ..moveTo(size.width * 0.5, size.height * 0.18)
      ..lineTo(size.width * 0.82, size.height * 0.3)
      ..lineTo(size.width * 0.75, size.height * 0.68)
      ..lineTo(size.width * 0.5, size.height * 0.86)
      ..lineTo(size.width * 0.25, size.height * 0.68)
      ..lineTo(size.width * 0.18, size.height * 0.3)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _drawSparkles(Canvas canvas, Size size, Paint paint) {
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    for (final offset in [
      Offset(size.width * 0.3, size.height * 0.35),
      Offset(size.width * 0.65, size.height * 0.25),
      Offset(size.width * 0.75, size.height * 0.6),
    ]) {
      _drawStar(canvas, offset, size.width * 0.06, fill);
    }
  }

  void _drawStar(Canvas canvas, Offset center, double radius, Paint paint) {
    const points = 4;
    final path = Path();
    for (var i = 0; i < points * 2; i++) {
      final r = i.isEven ? radius : radius * 0.4;
      final angle = (i * math.pi / points) - math.pi / 2;
      final point = Offset(
        center.dx + r * math.cos(angle),
        center.dy + r * math.sin(angle),
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WatermarkPainter oldDelegate) {
    return oldDelegate.motif != motif || oldDelegate.color != color;
  }
}
