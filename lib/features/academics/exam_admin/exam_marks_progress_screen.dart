import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/exams/exam_administration_store.dart';
import '../../../core/security/permissions.dart';
import '../../../core/security/rbac_service.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import 'exam_admin_navigation.dart';
import 'exam_administration_provider.dart';
import 'exam_marks_entry_provider.dart';

/// EXM-2 — marks-entry progress board. Lists every exam currently awaiting
/// marks with an entered/total progress bar + a pending count, so a coordinator
/// can see bottlenecks before processing/publishing. RBAC-gated on viewExams OR
/// verifyExamResults.
class ExamMarksProgressScreen extends ConsumerWidget {
  const ExamMarksProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rbac = ref.watch(rbacServiceProvider);
    final allowed = rbac.hasPermission(Permission.viewExams) ||
        rbac.hasPermission(Permission.verifyExamResults);

    return Scaffold(
      appBar: AppBar(title: const Text('Marks entry progress')),
      body: !allowed
          ? const AksharaEmptyState(
              message:
                  'You do not have permission to view marks-entry progress.',
              icon: Icons.lock_outline,
            )
          : ref.watch(examMarksEntryProgressProvider).when(
                loading: () => const AksharaLoadingState(
                  semanticLabel: 'Loading marks progress',
                ),
                error: (_, __) => AksharaErrorState(
                  message: 'Unable to load marks progress.',
                  onRetry: () => refreshExamAdminList(ref),
                ),
                data: (rows) {
                  if (rows.isEmpty) {
                    return const AksharaEmptyState(
                      message: 'No exams are awaiting marks.',
                      icon: Icons.checklist_rtl_outlined,
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(AksharaSpacing.s4),
                    itemCount: rows.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AksharaSpacing.s3),
                    itemBuilder: (context, index) =>
                        _ProgressCard(progress: rows[index]),
                  );
                },
              ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.progress});

  final MarksEntryProgress progress;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    final colors = context.colors;
    final complete = progress.pending == 0;

    return Card(
      key: QaTestKeys.examMarksProgressCard(progress.examId),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AksharaSpacing.s3),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AksharaSpacing.s3),
        onTap: () => openExamMarksEntry(context, progress.examId),
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(progress.title, style: text.titleMedium),
                  ),
                  AksharaStatusChip(
                    label: complete ? 'Complete' : '${progress.pending} pending',
                    tone: complete ? KpiAccent.success : KpiAccent.warning,
                  ),
                ],
              ),
              const SizedBox(height: AksharaSpacing.s2),
              Text(
                'Class ${progress.classLabel} · ${progress.subject}',
                style: text.bodyMedium,
              ),
              const SizedBox(height: AksharaSpacing.s3),
              ClipRRect(
                borderRadius: BorderRadius.circular(AksharaSpacing.s1),
                child: LinearProgressIndicator(
                  value: progress.fraction,
                  minHeight: 8,
                  backgroundColor: colors.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: AksharaSpacing.s2),
              Text(
                '${progress.enteredCount} / ${progress.totalCount} entered',
                style: text.bodySmall.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
