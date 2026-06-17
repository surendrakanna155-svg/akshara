import 'package:flutter/material.dart';

import '../../../shared/widgets/akshara_chart.dart';
import '../../../theme/motion.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../finance_models.dart';

/// Collection trend bar chart for FN-01 dashboard and shared ERP modules.
class FinanceCollectionTrendChart extends StatelessWidget {
  const FinanceCollectionTrendChart({
    super.key,
    required this.title,
    required this.points,
    this.height = 320,
    this.subtitle,
  });

  /// Total chart card footprint; drawable bar area is reduced for title and legend.
  static const double _cardChrome = 116;

  final String title;
  final List<CollectionTrendPoint> points;
  final double height;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ext = context.akshara;
    final isEmpty = points.isEmpty;
    final chartBodyHeight = (height - _cardChrome).clamp(120.0, height);

    return AksharaChartCard(
      title: title,
      subtitle: subtitle,
      semanticLabel: '$title chart, ${points.length} periods',
      emptyState: isEmpty
          ? const AksharaChartEmpty(
              message:
                  'Trend data will appear once collections are recorded for this period.',
              icon: Icons.bar_chart_rounded,
            )
          : null,
      height: isEmpty ? null : chartBodyHeight,
      legend: isEmpty
          ? null
          : AksharaChartLegend(
              items: [
                AksharaChartLegendItem(
                  color: ext.chart1,
                  label: 'Collected',
                ),
                AksharaChartLegendItem(
                  color: colors.outlineVariant.withValues(alpha: 0.55),
                  label: 'Target',
                ),
                AksharaChartLegendItem(
                  color: ext.chart2,
                  label: 'Performance',
                  value: _performanceLabel(points),
                ),
              ],
            ),
      child: isEmpty
          ? const SizedBox.shrink()
          : _TrendChartBody(
              points: points,
              collectedColor: ext.chart1,
              targetColor: colors.outlineVariant,
              gridColor: ext.chartGrid.withValues(alpha: 0.65),
            ),
    );
  }

  static String _performanceLabel(List<CollectionTrendPoint> points) {
    if (points.isEmpty) {
      return '—';
    }
    final latest = points.last;
    if (latest.targetLakhs <= 0) {
      return '—';
    }
    final pct =
        ((latest.amountLakhs / latest.targetLakhs) * 100).round().clamp(0, 999);
    return '$pct% of target';
  }
}

class _TrendChartBody extends StatelessWidget {
  const _TrendChartBody({
    required this.points,
    required this.collectedColor,
    required this.targetColor,
    required this.gridColor,
  });

  final List<CollectionTrendPoint> points;
  final Color collectedColor;
  final Color targetColor;
  final Color gridColor;

  @override
  Widget build(BuildContext context) {
    final maxValue = points
        .map((p) => p.amountLakhs > p.targetLakhs ? p.amountLakhs : p.targetLakhs)
        .fold<double>(0, (a, b) => a > b ? a : b);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: AksharaChartGridPainter(lineColor: gridColor),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < points.length; i++) ...[
                  Expanded(
                    child: _TrendBar(
                      point: points[i],
                      maxValue: maxValue,
                      collectedColor: collectedColor,
                      targetColor: targetColor,
                    ),
                  ),
                  if (i < points.length - 1)
                    const SizedBox(width: AksharaSpacing.s2),
                ],
              ],
            ),
          ],
        );
      },
    );
  }
}

class _TrendBar extends StatelessWidget {
  const _TrendBar({
    required this.point,
    required this.maxValue,
    required this.collectedColor,
    required this.targetColor,
  });

  final CollectionTrendPoint point;
  final double maxValue;
  final Color collectedColor;
  final Color targetColor;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    final colors = context.colors;
    final safeMax = maxValue <= 0 ? 1.0 : maxValue;
    final hitTarget = point.targetLakhs > 0 &&
        point.amountLakhs >= point.targetLakhs;

    return LayoutBuilder(
      builder: (context, constraints) {
        final barAreaHeight = (constraints.maxHeight - 44).clamp(72.0, 220.0);
        final collectedHeight =
            (point.amountLakhs / safeMax) * barAreaHeight;
        final targetHeight = (point.targetLakhs / safeMax) * barAreaHeight;

        return Semantics(
          label:
              '${point.label}: collected ${point.amountLakhs} lakhs, target ${point.targetLakhs} lakhs',
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                '₹${point.amountLakhs.toStringAsFixed(1)}L',
                style: text.labelSmall.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AksharaSpacing.s1),
              SizedBox(
                height: barAreaHeight,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    Container(
                      width: 30,
                      height: targetHeight,
                      decoration: BoxDecoration(
                        color: targetColor.withValues(alpha: 0.18),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(AksharaRadius.sm),
                        ),
                        border: Border.all(
                          color: targetColor.withValues(alpha: 0.35),
                        ),
                      ),
                    ),
                    AnimatedContainer(
                      duration: AksharaMotion.fast,
                      curve: AksharaMotion.emphasis,
                      width: 22,
                      height: collectedHeight,
                      decoration: BoxDecoration(
                        color: collectedColor.withValues(
                          alpha: hitTarget ? 1 : 0.88,
                        ),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(AksharaRadius.sm),
                        ),
                        boxShadow: hitTarget
                            ? [
                                BoxShadow(
                                  color: collectedColor.withValues(alpha: 0.25),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AksharaSpacing.s2),
              Text(
                point.label,
                style: text.labelMedium.copyWith(
                  color: colors.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }
}
