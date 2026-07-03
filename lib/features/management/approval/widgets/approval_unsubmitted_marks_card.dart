import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/exams/exam_administration_store.dart';
import '../../../../core/security/permissions.dart';
import '../../../../core/security/rbac_service.dart';
import '../../../../core/testing/qa_test_keys.dart';
import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import '../../../academics/exam_admin/exam_marks_entry_provider.dart';
import '../../../academics/exam_admin/exam_marks_progress_screen.dart';

/// PRI-2 — an "unsubmitted marks" exception card on the Principal Approval
/// Center. Reuses the existing marks-entry progress feed
/// ([examMarksEntryProgressProvider]), filtered to exams that still have pending
/// (unentered) marks, and links into the full marks-progress board.
///
/// Read-only. RBAC-gated on viewExams OR verifyExamResults (same as the
/// marks-progress screen) — hidden entirely when the user cannot view exams.
class ApprovalUnsubmittedMarksCard extends ConsumerWidget {
  const ApprovalUnsubmittedMarksCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rbac = ref.watch(rbacServiceProvider);
    final allowed = rbac.hasPermission(Permission.viewExams) ||
        rbac.hasPermission(Permission.verifyExamResults);
    if (!allowed) return const SizedBox.shrink();

    final async = ref.watch(examMarksEntryProgressProvider);
    // Only surface the card when there is at least one exam with pending marks;
    // stay quiet on loading / error / all-complete to avoid noise.
    final pendingExams = async.maybeWhen<List<MarksEntryProgress>>(
      data: (rows) => rows.where((row) => row.pending > 0).toList(),
      orElse: () => const <MarksEntryProgress>[],
    );
    if (pendingExams.isEmpty) return const SizedBox.shrink();

    final colors = context.colors;
    final text = context.aksharaText;
    final examCount = pendingExams.length;
    final totalPending =
        pendingExams.fold<int>(0, (sum, row) => sum + row.pending);
    final examWord = examCount == 1 ? 'exam' : 'exams';

    return Padding(
      padding: const EdgeInsets.only(bottom: AksharaSpacing.s4),
      child: Card(
        key: QaTestKeys.approvalUnsubmittedMarksCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AksharaSpacing.s3),
          side: BorderSide(color: colors.outlineVariant),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AksharaSpacing.s3),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const ExamMarksProgressScreen(),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AksharaSpacing.s4),
            child: Row(
              children: [
                Icon(Icons.assignment_late_outlined, color: colors.error),
                const SizedBox(width: AksharaSpacing.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Unsubmitted marks', style: text.titleSmall),
                      const SizedBox(height: AksharaSpacing.s1),
                      Text(
                        '$examCount $examWord awaiting marks · '
                        '$totalPending entries pending',
                        style: text.bodySmall.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
