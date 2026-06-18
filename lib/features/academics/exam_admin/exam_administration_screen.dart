import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/exams/exam_administration_store.dart';
import '../../../core/security/permissions.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/widgets/akshara_manage_action.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import 'exam_admin_models.dart';
import 'exam_administration_provider.dart';
import 'widgets/exam_create_dialog.dart';
import 'widgets/exam_lifecycle_actions.dart';

/// ERP exam scheduling and lifecycle administration.
class ExamAdministrationScreen extends ConsumerWidget {
  const ExamAdministrationScreen({super.key});

  static const phaseFilters = ExamAdminPhaseFilter.values;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(examAdminPhaseFilterProvider);
    final examsAsync = ref.watch(examAdminFilteredListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exam Administration'),
      ),
      floatingActionButton: AksharaManageAction(
        permission: Permission.manageExams,
        child: FloatingActionButton.extended(
          key: QaTestKeys.examAdminCreateButton,
          onPressed: () => showExamCreateDialog(context, ref),
          icon: const Icon(Icons.add),
          label: const Text('Create exam'),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AksharaSpacing.s4,
              vertical: AksharaSpacing.s3,
            ),
            child: Row(
              children: [
                for (final phase in phaseFilters)
                  Padding(
                    padding: const EdgeInsets.only(right: AksharaSpacing.s2),
                    child: FilterChip(
                      label: Text(phase.label),
                      selected: filter == phase,
                      onSelected: (_) => ref
                          .read(examAdminPhaseFilterProvider.notifier)
                          .state = phase,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: examsAsync.when(
              data: (exams) {
                if (exams.isEmpty) {
                  return const AksharaEmptyState(
                    message: 'No exams match this filter.',
                    icon: Icons.assignment_outlined,
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(AksharaSpacing.s4),
                  itemCount: exams.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AksharaSpacing.s3),
                  itemBuilder: (context, index) =>
                      _ExamSessionCard(exam: exams[index]),
                );
              },
              loading: () => const AksharaLoadingState(
                semanticLabel: 'Loading exams',
              ),
              error: (error, _) => AksharaErrorState(
                message: 'Unable to load exams.',
                onRetry: () => refreshExamAdminList(ref),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExamSessionCard extends ConsumerWidget {
  const _ExamSessionCard({required this.exam});

  final ExamSession exam;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = context.aksharaText;
    final colors = context.colors;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AksharaSpacing.s3),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AksharaSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(exam.title, style: text.titleMedium),
                ),
                AksharaStatusChip(
                  label: examPhaseLabel(exam.phase),
                  tone: KpiAccent.primary,
                ),
              ],
            ),
            const SizedBox(height: AksharaSpacing.s2),
            Text(
              'Class ${exam.classLabel} · ${exam.subject} · ${exam.examType.name}',
              style: text.bodyMedium,
            ),
            Text(
              '${exam.dateLabel} · ${exam.timeLabel} · ${exam.maxMarks} marks',
              style: text.bodySmall,
            ),
            Text(exam.venueLabel, style: text.bodySmall),
            const SizedBox(height: AksharaSpacing.s3),
            ExamLifecycleActions(exam: exam),
          ],
        ),
      ),
    );
  }
}
