import 'package:flutter/material.dart';

import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../finance_models.dart';

/// Collection trend bar chart for FN-01 dashboard.
class FinanceCollectionTrendChart extends StatelessWidget {
  const FinanceCollectionTrendChart({
    super.key,
    required this.title,
    required this.points,
    this.height = 320,
  });

  final String title;
  final List<CollectionTrendPoint> points;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;
    final ext = context.akshara;
    final maxValue = points
        .map((p) => p.amountLakhs > p.targetLakhs ? p.amountLakhs : p.targetLakhs)
        .fold<double>(0, (a, b) => a > b ? a : b);

    return Semantics(
      container: true,
      label: '$title chart, ${points.length} periods',
      child: Card(
        elevation: 0,
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AksharaRadius.lg),
          side: BorderSide(color: colors.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: text.titleMedium),
              const SizedBox(height: AksharaSpacing.s4),
              SizedBox(
                height: height,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final point in points) ...[
                      Expanded(
                        child: _TrendBar(
                          point: point,
                          maxValue: maxValue,
                          collectedColor: ext.chart1,
                          targetColor: colors.outlineVariant,
                        ),
                      ),
                      if (point != points.last)
                        const SizedBox(width: AksharaSpacing.s2),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AksharaSpacing.s3),
              Row(
                children: [
                  _LegendDot(color: ext.chart1, label: 'Collected'),
                  const SizedBox(width: AksharaSpacing.s4),
                  _LegendDot(color: colors.outlineVariant, label: 'Target'),
                ],
              ),
            ],
          ),
        ),
      ),
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
    final safeMax = maxValue <= 0 ? 1.0 : maxValue;

    return LayoutBuilder(
      builder: (context, constraints) {
        final barAreaHeight = (constraints.maxHeight - 40).clamp(60.0, 200.0);
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
                style: text.labelSmall,
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
                      width: 28,
                      height: targetHeight,
                      decoration: BoxDecoration(
                        color: targetColor.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(AksharaRadius.sm),
                      ),
                    ),
                    Container(
                      width: 20,
                      height: collectedHeight,
                      decoration: BoxDecoration(
                        color: collectedColor,
                        borderRadius: BorderRadius.circular(AksharaRadius.sm),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AksharaSpacing.s1),
              Text(
                point.label,
                style: text.labelSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AksharaSpacing.s2),
        Text(label, style: text.labelSmall),
      ],
    );
  }
}
