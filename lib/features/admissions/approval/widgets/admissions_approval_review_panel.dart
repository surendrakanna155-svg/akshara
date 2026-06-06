import 'package:flutter/material.dart';

import '../../../../shared/widgets/akshara_section_header.dart';
import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import '../../admissions_models.dart';

/// Application review panel with notes, workflow, and actions (AD-07).
class AdmissionsApprovalReviewPanel extends StatelessWidget {
  const AdmissionsApprovalReviewPanel({
    super.key,
    required this.review,
    this.onApprove,
    this.onReject,
  });

  final ApprovalReviewDetail review;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;
    final item = review.queueItem;

    return Semantics(
      container: true,
      label: 'Review panel for ${item.studentName}',
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AksharaSpacing.s3),
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                item.studentName,
                style: text.titleMedium.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                '${item.applicationId} · Class ${item.classLabel}',
                style: text.bodySmall.copyWith(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: AksharaSpacing.s3),
              _InfoLine(label: 'Parent', value: item.parentName),
              _InfoLine(label: 'Counselor', value: item.counselor),
              _InfoLine(label: 'Fee plan', value: review.feePlanLabel),
              _InfoLine(
                label: 'Documents',
                value: '${item.documentsComplete}/${item.documentsTotal}',
              ),
              const SizedBox(height: AksharaSpacing.s4),
              const AksharaSectionHeader(title: 'Status workflow'),
              const SizedBox(height: AksharaSpacing.s2),
              for (var i = 0; i < review.workflowSteps.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: AksharaSpacing.s1),
                  child: Row(
                    children: [
                      Icon(
                        i < 3 ? Icons.check_circle : Icons.radio_button_off,
                        size: 16,
                        color: i < 3 ? colors.primary : colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: AksharaSpacing.s2),
                      Expanded(child: Text(review.workflowSteps[i])),
                    ],
                  ),
                ),
              const SizedBox(height: AksharaSpacing.s4),
              const AksharaSectionHeader(title: 'Counselor notes'),
              const SizedBox(height: AksharaSpacing.s2),
              for (final note in review.counselorNotes)
                Padding(
                  padding: const EdgeInsets.only(bottom: AksharaSpacing.s3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${note.author} · ${note.timestampLabel}',
                        style: text.labelSmall.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      Text(note.content, style: text.bodyMedium),
                    ],
                  ),
                ),
              const SizedBox(height: AksharaSpacing.s4),
              const AksharaSectionHeader(title: 'Approval history'),
              const SizedBox(height: AksharaSpacing.s2),
              for (final record in review.history)
                Text(
                  '${record.timestampLabel} · ${record.actor}: ${record.comment}',
                  style: text.bodySmall,
                ),
              const SizedBox(height: AksharaSpacing.s4),
              Row(
                children: [
                  FilledButton(
                    onPressed: onApprove,
                    child: const Text('Approve'),
                  ),
                  const SizedBox(width: AksharaSpacing.s2),
                  OutlinedButton(
                    onPressed: onReject,
                    child: const Text('Reject'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AksharaSpacing.s1),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: context.aksharaText.bodySmall.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
