import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/exams/exam_administration_store.dart';
import '../../../core/security/permissions.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/async/erp_async_state.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../../shared/widgets/akshara_view_action.dart';
import '../../education/education_models.dart' show examTypeLabel;
import 'exam_admin_models.dart';
import 'exam_admin_navigation.dart';
import 'exam_administration_provider.dart';
import 'exam_settings_provider.dart';
import 'widgets/exam_create_dialog.dart';
import 'widgets/exam_lifecycle_actions.dart';
import 'widgets/exam_settings_sheet.dart';

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
        actions: [
          // EXM-3/4/5/7 — open the Exam Reports area (gated on viewExams).
          AksharaViewAction(
            permission: Permission.viewExams,
            child: IconButton(
              key: QaTestKeys.examReportsButton,
              icon: const Icon(Icons.assessment_outlined),
              tooltip: 'Exam reports',
              onPressed: () => openExamReports(context),
            ),
          ),
          IconButton(
            key: const Key('exam_settings_button'),
            icon: const Icon(Icons.tune),
            tooltip: 'Exam settings',
            onPressed: () => showExamSettingsSheet(context),
          ),
        ],
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
          const _ExamSettingsSummaryBar(),
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
            child: ErpAsyncBody(
              state: resolveErpAsync(
                examsAsync,
                isDataEmpty: (exams) => exams.isEmpty,
              ),
              loadingLabel: 'Loading exams',
              emptyMessage: 'No exams match this filter.',
              emptyIcon: Icons.assignment_outlined,
              onRetry: () => refreshExamAdminList(ref),
              builder: (exams) {
                return ListView.separated(
                  padding: const EdgeInsets.all(AksharaSpacing.s4),
                  itemCount: exams.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AksharaSpacing.s3),
                  itemBuilder: (context, index) =>
                      _ExamSessionCard(exam: exams[index]),
                );
              },
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
              'Class ${exam.classLabel} · ${exam.subject} · '
              '${examTypeLabel(exam.examType)}',
              style: text.bodyMedium,
            ),
            Text(
              '${exam.dateLabel} · ${exam.timeLabel} · ${exam.maxMarks} marks',
              style: text.bodySmall,
            ),
            Text(exam.venueLabel, style: text.bodySmall),
            _ExamApprovalStatusRow(exam: exam),
            const SizedBox(height: AksharaSpacing.s3),
            ExamLifecycleActions(exam: exam),
          ],
        ),
      ),
    );
  }
}

/// Approve → publish status surfaced on each exam card so coordinators and
/// principals see what an exam is waiting on without leaving the workspace.
/// Hidden for early phases (draft/scheduled/marks-in-progress) where the phase
/// chip already says everything.
class _ExamApprovalStatusRow extends StatelessWidget {
  const _ExamApprovalStatusRow({required this.exam});

  final ExamSession exam;

  @override
  Widget build(BuildContext context) {
    final status = examApprovalStatus(exam);
    if (status == ExamApprovalStatus.none ||
        status == ExamApprovalStatus.marksInProgress) {
      return const SizedBox.shrink();
    }

    final colors = context.colors;
    final text = context.aksharaText;
    final rejection = exam.rejectionComment;
    final showFeedback = status == ExamApprovalStatus.returned &&
        rejection != null &&
        rejection.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(top: AksharaSpacing.s3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AksharaStatusChip(
            key: QaTestKeys.examAdminApprovalStatusChip(exam.id),
            label: examApprovalStatusLabel(status),
            tone: _approvalStatusTone(status),
          ),
          if (showFeedback) ...[
            const SizedBox(height: AksharaSpacing.s2),
            Text(
              'Principal feedback: $rejection',
              style: text.bodySmall.copyWith(color: colors.error),
            ),
          ],
        ],
      ),
    );
  }
}

KpiAccent _approvalStatusTone(ExamApprovalStatus status) => switch (status) {
      ExamApprovalStatus.published => KpiAccent.success,
      ExamApprovalStatus.returned => KpiAccent.error,
      ExamApprovalStatus.awaitingApproval => KpiAccent.warning,
      ExamApprovalStatus.awaitingVerification => KpiAccent.warning,
      ExamApprovalStatus.marksInProgress => KpiAccent.neutral,
      ExamApprovalStatus.none => KpiAccent.neutral,
    };

/// Compact "current exam settings" bar — shows the school's grading style and
/// rank visibility at a glance, and opens the Exam Settings sheet on tap.
class _ExamSettingsSummaryBar extends ConsumerWidget {
  const _ExamSettingsSummaryBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(examReportSettingsProvider);
    final text = context.aksharaText;
    final colors = context.colors;

    return Material(
      color: colors.surfaceContainerHighest,
      child: InkWell(
        onTap: () => showExamSettingsSheet(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AksharaSpacing.s4,
            vertical: AksharaSpacing.s2,
          ),
          child: Row(
            children: [
              Icon(Icons.tune, size: 18, color: colors.onSurfaceVariant),
              const SizedBox(width: AksharaSpacing.s2),
              Expanded(
                child: Text(
                  'Grading: ${settings.gradingScale.name}  ·  '
                  'Rank: ${settings.showRankToParents ? 'shown to parents' : 'hidden'}',
                  style: text.bodySmall.copyWith(color: colors.onSurfaceVariant),
                ),
              ),
              Text('Change', style: text.labelSmall.copyWith(color: colors.primary)),
            ],
          ),
        ),
      ),
    );
  }
}
