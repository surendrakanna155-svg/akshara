import 'package:flutter/material.dart';

import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import '../../../../theme/typography.dart';
import '../../admissions_models.dart';

/// Activity timeline for AD-04 lead detail.
class AdmissionsLeadTimeline extends StatelessWidget {
  const AdmissionsLeadTimeline({
    super.key,
    required this.activities,
  });

  final List<LeadActivityItem> activities;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Semantics(
      container: true,
      label: 'Activity timeline, ${activities.length} events',
      child: Column(
        children: [
          for (var i = 0; i < activities.length; i++) ...[
            _TimelineRow(
              activity: activities[i],
              isLast: i == activities.length - 1,
              colors: colors,
              text: text,
            ),
          ],
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.activity,
    required this.isLast,
    required this.colors,
    required this.text,
  });

  final LeadActivityItem activity;
  final bool isLast;
  final ColorScheme colors;
  final AksharaTextStyles text;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    activity.type.icon,
                    size: 16,
                    color: colors.primary,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: colors.outlineVariant,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: isLast ? 0 : AksharaSpacing.s4,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.title,
                    style: text.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${activity.timestampLabel} · ${activity.actor}',
                    style: text.bodySmall.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AksharaSpacing.s1),
                  Text(
                    activity.description,
                    style: text.bodySmall.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
