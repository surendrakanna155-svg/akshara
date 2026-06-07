import 'package:flutter/material.dart';

import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../transport_models.dart';

/// Segment breakdown panel for transport dashboards and reports.
class TransportSegmentPanel extends StatelessWidget {
  const TransportSegmentPanel({
    super.key,
    required this.title,
    required this.segments,
    this.height = 320,
  });

  final String title;
  final List<TransportSegment> segments;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Semantics(
      container: true,
      label: '$title breakdown, ${segments.length} segments',
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AksharaRadius.lg),
          side: BorderSide(color: colors.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s5),
          child: SizedBox(
            height: height,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: text.titleMedium),
                const SizedBox(height: AksharaSpacing.s4),
                Expanded(
                  child: ListView.separated(
                    itemCount: segments.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AksharaSpacing.s3),
                    itemBuilder: (context, index) {
                      final segment = segments[index];
                      return Semantics(
                        label:
                            '${segment.label}: ${segment.percent.toStringAsFixed(0)} percent',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    segment.label,
                                    style: text.bodyMedium,
                                  ),
                                ),
                                Text(
                                  '${segment.percent.toStringAsFixed(0)}%',
                                  style: text.titleSmall,
                                ),
                              ],
                            ),
                            const SizedBox(height: AksharaSpacing.s1),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: segment.percent / 100,
                                minHeight: 8,
                                backgroundColor: colors.surfaceContainerHighest,
                                color: colors.primary,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
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
