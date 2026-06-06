import 'package:flutter/material.dart';

import '../../../../theme/radius.dart';
import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import '../student_dashboard_provider.dart';

/// Upcoming exam reminder card for student dashboard.
class ExamReminderCard extends StatelessWidget {
  const ExamReminderCard({
    super.key,
    required this.reminder,
    this.onTap,
  });

  final ExamReminder reminder;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Semantics(
      button: onTap != null,
      label:
          'Exam reminder: ${reminder.title}, ${reminder.subject}, '
          '${reminder.dateLabel}, in ${reminder.daysUntil} days',
      child: Material(
        color: colors.secondaryContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AksharaRadius.card,
          side: BorderSide(
            color: colors.secondary.withValues(alpha: 0.3),
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: AksharaRadius.card,
          child: Padding(
            padding: const EdgeInsets.all(AksharaSpacing.s4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colors.secondary.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.event_note_outlined,
                    size: 22,
                    color: colors.secondary,
                  ),
                ),
                const SizedBox(width: AksharaSpacing.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AksharaSpacing.s2,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colors.surface,
                              borderRadius: AksharaRadius.chip,
                            ),
                            child: Text(
                              'Exam',
                              style: text.labelSmall.copyWith(
                                color: colors.secondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'In ${reminder.daysUntil} days',
                            style: text.labelSmall.copyWith(
                              color: colors.onSecondaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AksharaSpacing.s2),
                      Text(
                        reminder.title,
                        style: text.titleSmall.copyWith(
                          color: colors.onSecondaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AksharaSpacing.s1),
                      Text(
                        reminder.subject,
                        style: text.bodySmall.copyWith(
                          color: colors.onSecondaryContainer.withValues(
                            alpha: 0.85,
                          ),
                        ),
                      ),
                      const SizedBox(height: AksharaSpacing.s1),
                      Text(
                        reminder.dateLabel,
                        style: text.bodySmall.copyWith(
                          color: colors.onSecondaryContainer.withValues(
                            alpha: 0.75,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: colors.onSecondaryContainer.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
