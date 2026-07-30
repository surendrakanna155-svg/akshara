import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/theme_extensions.dart';

/// A premium circular progress ring (donut gauge) with a rounded value arc over
/// a soft track, and any [child] centered inside (typically a big number + a
/// caption). A flagship data-viz primitive for dashboard headline metrics —
/// reusable across personas. Presentation only.
///
/// [value] is 0..1 (clamped). [color] defaults to the theme primary (the persona
/// accent). The arc sweeps clockwise from 12 o'clock.
class AksharaProgressRing extends StatelessWidget {
  const AksharaProgressRing({
    super.key,
    required this.value,
    this.size = 96,
    this.strokeWidth = 9,
    this.color,
    this.trackColor,
    this.child,
    this.semanticLabel,
  });

  final double value;
  final double size;
  final double strokeWidth;
  final Color? color;
  final Color? trackColor;
  final Widget? child;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final arc = color ?? colors.primary;
    final track = trackColor ?? colors.surfaceContainerHighest;

    // Grow the ring with the user's text scale (clamped) so a large-accessibility
    // centered label keeps headroom, and scale-down the label as a hard backstop
    // so it can never overflow the fixed circle.
    final scale = MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.5);
    final scaledSize = size * scale;
    final scaledStroke = strokeWidth * scale;

    final ring = SizedBox(
      width: scaledSize,
      height: scaledSize,
      child: CustomPaint(
        painter: _RingPainter(
          value: value.clamp(0.0, 1.0),
          strokeWidth: scaledStroke,
          arcColor: arc,
          trackColor: track,
        ),
        child: child == null
            ? null
            : Center(
                child: Padding(
                  padding: EdgeInsets.all(scaledStroke + 4),
                  child: FittedBox(fit: BoxFit.scaleDown, child: child),
                ),
              ),
      ),
    );

    if (semanticLabel == null) return ring;
    return Semantics(
      label: semanticLabel,
      value: '${(value * 100).round()}%',
      child: ring,
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.value,
    required this.strokeWidth,
    required this.arcColor,
    required this.trackColor,
  });

  final double value;
  final double strokeWidth;
  final Color arcColor;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final arcRect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = trackColor;
    canvas.drawArc(arcRect, 0, 2 * math.pi, false, trackPaint);

    if (value <= 0) return;

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = arcColor;
    // Start at 12 o'clock (-90°), sweep clockwise.
    canvas.drawArc(
      arcRect,
      -math.pi / 2,
      2 * math.pi * value,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value ||
      old.strokeWidth != strokeWidth ||
      old.arcColor != arcColor ||
      old.trackColor != trackColor;
}
