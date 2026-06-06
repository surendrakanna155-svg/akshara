import 'package:flutter/material.dart';

import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../../theme/typography.dart';
import '../admissions_models.dart';

/// Mock chart panel for funnel or source donut visualizations.
class AdmissionsChartPanel extends StatelessWidget {
  const AdmissionsChartPanel({
    super.key,
    required this.title,
    required this.segments,
    this.height = 320,
    this.chartType = AdmissionsChartType.funnel,
  });

  final String title;
  final List<ChartSegment> segments;
  final double height;
  final AdmissionsChartType chartType;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;
    final ext = context.akshara;
    final chartColors = [ext.chart1, ext.chart2, ext.chart3, ext.chart4];

    return Semantics(
      container: true,
      label: '$title chart with ${segments.length} segments',
      child: Material(
        color: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AksharaRadius.card,
          side: BorderSide(color: colors.outlineVariant),
        ),
        child: SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.all(AksharaSpacing.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: text.titleSmall.copyWith(color: colors.onSurface),
                ),
                const SizedBox(height: AksharaSpacing.s4),
                Expanded(
                  child: chartType == AdmissionsChartType.funnel
                      ? _FunnelChart(
                          segments: segments,
                          colors: chartColors,
                          text: text,
                          onSurfaceVariant: colors.onSurfaceVariant,
                        )
                      : _DonutLegend(
                          segments: segments,
                          colors: chartColors,
                          text: text,
                          onSurfaceVariant: colors.onSurfaceVariant,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum AdmissionsChartType { funnel, donut }

class _FunnelChart extends StatelessWidget {
  const _FunnelChart({
    required this.segments,
    required this.colors,
    required this.text,
    required this.onSurfaceVariant,
  });

  final List<ChartSegment> segments;
  final List<Color> colors;
  final AksharaTextStyles text;
  final Color onSurfaceVariant;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 3,
          child: Column(
            children: [
              for (var i = 0; i < segments.length; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final widthFactor =
                            segments[i].percent / (segments.first.percent);
                        return Align(
                          alignment: Alignment.center,
                          child: Container(
                            width: constraints.maxWidth * widthFactor,
                            decoration: BoxDecoration(
                              color: colors[i % colors.length]
                                  .withValues(alpha: 0.85),
                              borderRadius: AksharaRadius.chip,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: AksharaSpacing.s4),
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < segments.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: AksharaSpacing.s2),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: colors[i % colors.length],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: AksharaSpacing.s2),
                      Expanded(
                        child: Text(
                          '${segments[i].label} · ${segments[i].value}',
                          style: text.bodySmall.copyWith(
                            color: onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DonutLegend extends StatelessWidget {
  const _DonutLegend({
    required this.segments,
    required this.colors,
    required this.text,
    required this.onSurfaceVariant,
  });

  final List<ChartSegment> segments;
  final List<Color> colors;
  final AksharaTextStyles text;
  final Color onSurfaceVariant;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AspectRatio(
            aspectRatio: 1,
            child: CustomPaint(
              painter: _DonutPainter(
                segments: segments,
                colors: colors,
              ),
            ),
          ),
        ),
        const SizedBox(width: AksharaSpacing.s4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < segments.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: AksharaSpacing.s1),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: colors[i % colors.length],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: AksharaSpacing.s2),
                      Expanded(
                        child: Text(
                          '${segments[i].label} ${segments[i].percent.toStringAsFixed(1)}%',
                          style: text.bodySmall.copyWith(
                            color: onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.segments, required this.colors});

  final List<ChartSegment> segments;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;
    const stroke = 28.0;
    var start = -1.5708;

    for (var i = 0; i < segments.length; i++) {
      final sweep = (segments[i].percent / 100) * 6.28318;
      final paint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - stroke / 2),
        start,
        sweep,
        false,
        paint,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) => false;
}
