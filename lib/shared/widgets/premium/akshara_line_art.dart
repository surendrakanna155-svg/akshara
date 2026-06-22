import 'package:flutter/material.dart';

import '../../../theme/premium_tokens.dart';

/// The Premium School OS line-art illustration language.
///
/// One single-weight monoline motif per module, drawn from the same kit so the
/// language stays consistent. Used faint as decorative backdrops (hero cards,
/// section backgrounds) and at full strength in empty states. Pure [CustomPaint]
/// — no asset/network dependency, tints to the active theme, and the AI School
/// Builder can map a school type → a motif pack later.
enum AksharaMotif {
  /// Academics / overview.
  graduationCap,

  /// Homework / library.
  book,

  /// Finance / intelligence.
  chart,

  /// Growth / Student 360.
  growth,

  /// Transport.
  bus,

  /// Library shelves.
  bookshelf,

  /// Hostel / campus / residence.
  campus,

  /// Communication / messaging.
  message,

  /// AI / connected-graph motif.
  nodes,

  /// AI spark.
  spark,
}

/// Renders an [AksharaMotif] as a monoline drawing.
///
/// Defaults to the theme line-art stroke at very low opacity (decorative). Pass
/// [decorative] = false (and an [opacity]) for the bold empty-state usage.
class AksharaLineArt extends StatelessWidget {
  const AksharaLineArt({
    super.key,
    required this.motif,
    this.size = 96,
    this.color,
    this.opacity,
    this.strokeWidth = 2,
  });

  final AksharaMotif motif;
  final double size;
  final Color? color;
  final double? opacity;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final premium = context.premiumOrNull;
    final stroke = color ?? premium?.lineArtStroke ?? const Color(0xFF5B5BF0);
    final resolvedOpacity = opacity ?? premium?.lineArtOpacity ?? 0.10;
    return IgnorePointer(
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _MotifPainter(
            motif: motif,
            color: stroke.withValues(alpha: resolvedOpacity),
            strokeWidth: strokeWidth,
          ),
        ),
      ),
    );
  }
}

class _MotifPainter extends CustomPainter {
  _MotifPainter({
    required this.motif,
    required this.color,
    required this.strokeWidth,
  });

  final AksharaMotif motif;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    // All paths are authored on a 100×100 grid then scaled to fit [size].
    final scale = size.width / 100.0;
    canvas.save();
    canvas.scale(scale, size.height / 100.0);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth / scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final dotPaint = Paint()..color = color;

    switch (motif) {
      case AksharaMotif.graduationCap:
        canvas.drawPath(
          Path()
            ..moveTo(10, 38)
            ..lineTo(50, 22)
            ..lineTo(90, 38)
            ..lineTo(50, 54)
            ..close(),
          paint,
        );
        canvas.drawPath(
          Path()
            ..moveTo(30, 46)
            ..lineTo(30, 66)
            ..cubicTo(30, 72, 70, 72, 70, 66)
            ..lineTo(70, 46),
          paint,
        );
        canvas.drawLine(const Offset(90, 38), const Offset(90, 58), paint);
        canvas.drawCircle(const Offset(90, 61), 3, dotPaint);
      case AksharaMotif.book:
        canvas.drawPath(
          Path()
            ..moveTo(50, 28)
            ..cubicTo(40, 22, 22, 22, 14, 26)
            ..lineTo(14, 74)
            ..cubicTo(22, 70, 40, 70, 50, 76)
            ..cubicTo(60, 70, 78, 70, 86, 74)
            ..lineTo(86, 26)
            ..cubicTo(78, 22, 60, 22, 50, 28)
            ..close(),
          paint,
        );
        canvas.drawLine(const Offset(50, 28), const Offset(50, 76), paint);
        for (final y in [38.0, 48.0, 58.0]) {
          canvas.drawLine(Offset(22, y), Offset(40, y), paint);
          canvas.drawLine(Offset(60, y), Offset(78, y), paint);
        }
      case AksharaMotif.chart:
        canvas.drawLine(const Offset(16, 84), const Offset(88, 84), paint);
        canvas.drawLine(const Offset(16, 84), const Offset(16, 18), paint);
        canvas.drawPath(
          Path()
            ..moveTo(28, 70)
            ..lineTo(46, 52)
            ..lineTo(60, 62)
            ..lineTo(84, 30),
          paint,
        );
        canvas.drawPath(
          Path()
            ..moveTo(74, 30)
            ..lineTo(86, 30)
            ..lineTo(86, 42),
          paint,
        );
      case AksharaMotif.growth:
        canvas.drawLine(const Offset(16, 84), const Offset(88, 84), paint);
        for (var i = 0; i < 3; i++) {
          final x = 30.0 + i * 22;
          final h = 24.0 + i * 16;
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x, 84 - h, 14, h),
              const Radius.circular(4),
            ),
            paint,
          );
        }
      case AksharaMotif.bus:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(14, 26, 72, 38),
            const Radius.circular(9),
          ),
          paint,
        );
        canvas.drawLine(const Offset(22, 40), const Offset(78, 40), paint);
        canvas.drawLine(const Offset(40, 26), const Offset(40, 40), paint);
        canvas.drawLine(const Offset(58, 26), const Offset(58, 40), paint);
        canvas.drawCircle(const Offset(34, 70), 6, paint);
        canvas.drawCircle(const Offset(66, 70), 6, paint);
      case AksharaMotif.bookshelf:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(18, 20, 64, 60),
            const Radius.circular(6),
          ),
          paint,
        );
        canvas.drawLine(const Offset(18, 50), const Offset(82, 50), paint);
        for (final x in [26.0, 34.0, 42.0]) {
          canvas.drawLine(Offset(x, 26), Offset(x, 44), paint);
          canvas.drawLine(Offset(x + 24, 56), Offset(x + 24, 74), paint);
        }
      case AksharaMotif.campus:
        canvas.drawPath(
          Path()
            ..moveTo(20, 50)
            ..lineTo(50, 28)
            ..lineTo(80, 50),
          paint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(28, 50, 44, 30),
            const Radius.circular(4),
          ),
          paint,
        );
        canvas.drawLine(const Offset(46, 80), const Offset(46, 62), paint);
        canvas.drawLine(const Offset(54, 80), const Offset(54, 62), paint);
        canvas.drawLine(const Offset(50, 28), const Offset(50, 18), paint);
      case AksharaMotif.message:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(16, 24, 68, 46),
            const Radius.circular(12),
          ),
          paint,
        );
        canvas.drawPath(
          Path()
            ..moveTo(34, 70)
            ..lineTo(34, 82)
            ..lineTo(48, 70),
          paint,
        );
        for (final y in [40.0, 52.0]) {
          canvas.drawLine(Offset(30, y), Offset(70, y), paint);
        }
      case AksharaMotif.nodes:
        final pts = const [
          Offset(20, 30),
          Offset(52, 18),
          Offset(84, 34),
          Offset(86, 70),
          Offset(54, 84),
          Offset(22, 66),
        ];
        for (final pair in [
          [0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [5, 0],
          [1, 4], [0, 2], [2, 5],
        ]) {
          canvas.drawLine(pts[pair[0]], pts[pair[1]], paint);
        }
        for (final p in pts) {
          canvas.drawCircle(p, 3.4, dotPaint);
        }
      case AksharaMotif.spark:
        canvas.drawLine(const Offset(50, 16), const Offset(50, 34), paint);
        canvas.drawLine(const Offset(50, 66), const Offset(50, 84), paint);
        canvas.drawLine(const Offset(16, 50), const Offset(34, 50), paint);
        canvas.drawLine(const Offset(66, 50), const Offset(84, 50), paint);
        canvas.drawLine(const Offset(28, 28), const Offset(40, 40), paint);
        canvas.drawLine(const Offset(60, 60), const Offset(72, 72), paint);
        canvas.drawLine(const Offset(72, 28), const Offset(60, 40), paint);
        canvas.drawLine(const Offset(40, 60), const Offset(28, 72), paint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_MotifPainter oldDelegate) =>
      oldDelegate.motif != motif ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth;
}
