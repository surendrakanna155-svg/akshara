import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/theme_extensions.dart';

/// Compact sparkline for executive KPI cards (M15.5).
class AksharaSparkline extends StatelessWidget {
  const AksharaSparkline({
    super.key,
    required this.points,
    this.height = 28,
    this.color,
    this.fill = true,
  });

  final List<double> points;
  final double height;
  final Color? color;
  final bool fill;

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) return SizedBox(height: height);

    final lineColor = color ?? context.colors.primary;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _SparklinePainter(
          points: points,
          lineColor: lineColor,
          fill: fill,
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.points,
    required this.lineColor,
    required this.fill,
  });

  final List<double> points;
  final Color lineColor;
  final bool fill;

  @override
  void paint(Canvas canvas, Size size) {
    final minY = points.reduce(math.min);
    final maxY = points.reduce(math.max);
    final range = (maxY - minY).abs() < 0.001 ? 1.0 : maxY - minY;

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = size.width * (i / (points.length - 1));
      final y = size.height - ((points[i] - minY) / range) * (size.height - 4) - 2;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    if (fill) {
      final fillPath = Path.from(path)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(
        fillPath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              lineColor.withValues(alpha: 0.22),
              lineColor.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
      );
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.fill != fill;
  }
}
