import 'package:flutter/material.dart';

import '../../../../shared/widgets/akshara_status_chip.dart';
import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import '../homework_models.dart';

class HomeworkSubmissionRow extends StatelessWidget {
  const HomeworkSubmissionRow({
    super.key,
    required this.submission,
    this.onReview,
  });

  final HomeworkSubmission submission;
  final VoidCallback? onReview;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;
    final isPending = submission.status == HomeworkReviewStatus.pending;

    return Semantics(
      button: onReview != null,
      label: '${submission.studentName}, ${submission.status.label}',
      child: Material(
        color: colors.surface,
        child: InkWell(
          onTap: onReview,
          child: Padding(
            padding: const EdgeInsets.all(AksharaSpacing.s4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        submission.studentName,
                        style: text.titleSmall.copyWith(
                          color: colors.onSurface,
                        ),
                      ),
                      Text(
                        submission.submittedLabel,
                        style: text.bodySmall.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      if (submission.grade != null)
                        Text(
                          'Grade ${submission.grade} · ${submission.comment ?? ''}',
                          style: text.bodySmall.copyWith(color: colors.primary),
                        ),
                    ],
                  ),
                ),
                AksharaStatusChip(
                  label: isPending ? 'Pending' : 'Reviewed',
                  tone: isPending ? KpiAccent.warning : KpiAccent.success,
                  size: AksharaStatusChipSize.compact,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
