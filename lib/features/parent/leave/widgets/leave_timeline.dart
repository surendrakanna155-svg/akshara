import 'package:flutter/material.dart';

import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import '../leave_models.dart';

/// Approval timeline for a leave request.
class LeaveTimeline extends StatelessWidget {
  const LeaveTimeline({
    super.key,
    required this.steps,
  });

  final List<LeaveTimelineStep> steps;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;
    final ext = context.akshara;

    return Semantics(
      container: true,
      label: 'Leave approval timeline',
      child: Column(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: steps[i].isComplete
                            ? ext.success
                            : colors.outlineVariant,
                        shape: BoxShape.circle,
                      ),
                    ),
                    if (i < steps.length - 1)
                      Container(
                        width: 2,
                        height: 40,
                        color: steps[i].isComplete
                            ? ext.success.withValues(alpha: 0.4)
                            : colors.outlineVariant,
                      ),
                  ],
                ),
                const SizedBox(width: AksharaSpacing.s3),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AksharaSpacing.s3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          steps[i].label,
                          style: text.bodyMedium.copyWith(
                            color: colors.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          steps[i].dateLabel,
                          style: text.bodySmall.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        if (steps[i].note != null) ...[
                          const SizedBox(height: AksharaSpacing.s1),
                          Text(
                            steps[i].note!,
                            style: text.bodySmall.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
