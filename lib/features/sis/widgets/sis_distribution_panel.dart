import 'package:flutter/material.dart';

import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../sis_models.dart';

/// Class or gender distribution panel for SIS-01 dashboard.
class SisDistributionPanel extends StatelessWidget {
  const SisDistributionPanel({
    super.key,
    required this.title,
    required this.segments,
    this.height = 240,
  });

  final String title;
  final List<DistributionSegment> segments;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;
    final ext = context.akshara;
    final chartColors = [ext.chart1, ext.chart2, ext.chart3, ext.chart4];

    return Semantics(
      container: true,
      label: '$title distribution, ${segments.length} segments',
      child: Card(
        elevation: 0,
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
                child: Column(
                  children: [
                    for (var i = 0; i < segments.length; i++) ...[
                      _DistributionBar(
                        segment: segments[i],
                        color: chartColors[i % chartColors.length],
                      ),
                      if (i < segments.length - 1)
                        const SizedBox(height: AksharaSpacing.s3),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DistributionBar extends StatelessWidget {
  const _DistributionBar({
    required this.segment,
    required this.color,
  });

  final DistributionSegment segment;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;

    return Semantics(
      label: '${segment.label}: ${segment.count} students, ${segment.percent}%',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(segment.label, style: text.labelMedium),
              ),
              Text(
                '${segment.count} (${segment.percent.toStringAsFixed(0)}%)',
                style: text.labelSmall,
              ),
            ],
          ),
          const SizedBox(height: AksharaSpacing.s1),
          ClipRRect(
            borderRadius: BorderRadius.circular(AksharaRadius.sm),
            child: LinearProgressIndicator(
              value: segment.percent / 100,
              minHeight: 8,
              backgroundColor: context.colors.surfaceContainerHighest,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
