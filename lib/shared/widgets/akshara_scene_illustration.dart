import 'package:flutter/material.dart';

import '../../theme/theme_extensions.dart';

/// Lightweight vector-style scene illustrations for heroes and empty states (M15.5).
class AksharaSceneIllustration extends StatelessWidget {
  const AksharaSceneIllustration({
    super.key,
    required this.variant,
    this.size = 120,
  });

  final AksharaSceneVariant variant;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ScenePainter(
          variant: variant,
          primary: colors.primary,
          secondary: colors.tertiary,
          surface: colors.surfaceContainerHighest,
        ),
      ),
    );
  }
}

enum AksharaSceneVariant {
  aiAssistant,
  emptyDashboard,
  learningMission,
}

class _ScenePainter extends CustomPainter {
  _ScenePainter({
    required this.variant,
    required this.primary,
    required this.secondary,
    required this.surface,
  });

  final AksharaSceneVariant variant;
  final Color primary;
  final Color secondary;
  final Color surface;

  @override
  void paint(Canvas canvas, Size size) {
    switch (variant) {
      case AksharaSceneVariant.aiAssistant:
        _paintAi(canvas, size);
      case AksharaSceneVariant.emptyDashboard:
        _paintEmpty(canvas, size);
      case AksharaSceneVariant.learningMission:
        _paintMission(canvas, size);
    }
  }

  void _paintAi(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.52);
    canvas.drawCircle(
      center,
      size.width * 0.28,
      Paint()..color = primary.withValues(alpha: 0.15),
    );
    canvas.drawCircle(
      center,
      size.width * 0.2,
      Paint()..color = surface,
    );
    final stroke = Paint()
      ..color = primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    canvas.drawCircle(center, size.width * 0.2, stroke);
    canvas.drawLine(
      Offset(center.dx - size.width * 0.08, center.dy),
      Offset(center.dx + size.width * 0.08, center.dy),
      stroke,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - size.width * 0.08),
      Offset(center.dx, center.dy + size.width * 0.08),
      stroke,
    );
  }

  void _paintEmpty(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.18, size.height * 0.22, size.width * 0.64,
          size.height * 0.5),
      const Radius.circular(12),
    );
    canvas.drawRRect(rect, Paint()..color = surface);
    canvas.drawRRect(
      rect,
      Paint()
        ..color = secondary.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawLine(
      Offset(size.width * 0.28, size.height * 0.38),
      Offset(size.width * 0.72, size.height * 0.38),
      Paint()
        ..color = primary.withValues(alpha: 0.45)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  void _paintMission(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.5, size.height * 0.18)
      ..lineTo(size.width * 0.78, size.height * 0.42)
      ..lineTo(size.width * 0.65, size.height * 0.78)
      ..lineTo(size.width * 0.35, size.height * 0.78)
      ..lineTo(size.width * 0.22, size.height * 0.42)
      ..close();
    canvas.drawPath(path, Paint()..color = primary.withValues(alpha: 0.12));
    canvas.drawPath(
      path,
      Paint()
        ..color = primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _ScenePainter oldDelegate) => false;
}
