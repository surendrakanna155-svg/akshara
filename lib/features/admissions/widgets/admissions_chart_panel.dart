import 'package:flutter/material.dart';

import '../../../shared/widgets/akshara_chart.dart';
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
    final ext = context.akshara;
    final chartColors = [ext.chart1, ext.chart2, ext.chart3, ext.chart4];
    final isEmpty = segments.isEmpty;

    if (isEmpty) {
      return AksharaChartCard(
        title: title,
        semanticLabel: '$title chart with 0 segments',
        emptyState: const AksharaChartEmpty(
          message:
              'Segment data will appear once admissions activity is recorded.',
          icon: Icons.donut_large_outlined,
        ),
        child: const SizedBox.shrink(),
      );
    }

    return SizedBox(
      height: height,
      child: AksharaChartCard(
        title: title,
        semanticLabel: '$title chart with ${segments.length} segments',
        expandBody: true,
        legend: AksharaChartLegend(
          items: [
            for (var i = 0; i < segments.length; i++)
              AksharaChartLegendItem(
                color: chartColors[i % chartColors.length],
                label: segments[i].label,
                value: chartType == AdmissionsChartType.donut
                    ? '${segments[i].percent.toStringAsFixed(1)}%'
                    : segments[i].value.toString(),
              ),
          ],
        ),
        child: chartType == AdmissionsChartType.funnel
            ? _FunnelChart(
                segments: segments,
                colors: chartColors,
                text: context.aksharaText,
              )
            : _DonutLegend(
                segments: segments,
                colors: chartColors,
                text: context.aksharaText,
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
  });

  final List<ChartSegment> segments;
  final List<Color> colors;
  final AksharaTextStyles text;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < segments.length; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final widthFactor =
                      segments[i].percent / (segments.first.percent);
                  return Align(
                    alignment: Alignment.center,
                    child: Container(
                      height: constraints.maxHeight,
                      width: constraints.maxWidth * widthFactor,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            colors[i % colors.length].withValues(alpha: 0.72),
                            colors[i % colors.length],
                          ],
                        ),
                        borderRadius: AksharaRadius.kpiCard,
                        boxShadow: [
                          BoxShadow(
                            color: colors[i % colors.length]
                                .withValues(alpha: 0.12),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AksharaSpacing.s3,
                      ),
                      child: Text(
                        segments[i].label,
                        style: text.labelSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  );
                },
              ),
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
  });

  final List<ChartSegment> segments;
  final List<Color> colors;
  final AksharaTextStyles text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Row(
      children: [
        Expanded(
          child: AspectRatio(
            aspectRatio: 1,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  painter: _DonutPainter(
                    segments: segments,
                    colors: this.colors,
                  ),
                  size: Size.infinite,
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${segments.length}',
                      style: text.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'sources',
                      style: text.labelSmall.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
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
  static const _gapRadians = 0.05;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;
    const stroke = 26.0;
    var start = -1.5708;

    for (var i = 0; i < segments.length; i++) {
      final rawSweep = (segments[i].percent / 100) * 6.28318;
      final sweep = (rawSweep - _gapRadians).clamp(0.02, rawSweep);
      final paint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - stroke / 2),
        start + _gapRadians / 2,
        sweep,
        false,
        paint,
      );
      start += rawSweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) => false;
}
