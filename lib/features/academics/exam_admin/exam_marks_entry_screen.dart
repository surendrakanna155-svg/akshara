import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/reports/akshara_report_export_service.dart';
import '../../../core/config/exam_approval_config.dart';
import '../../../core/exams/exam_administration_store.dart';
import '../../../core/security/permissions.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/widgets/akshara_view_action.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import 'exam_admin_models.dart';
import 'exam_administration_provider.dart';
import 'exam_marks_entry_provider.dart';

/// ERP marks entry and publication chain for a single exam session.
class ExamMarksEntryScreen extends ConsumerWidget {
  const ExamMarksEntryScreen({super.key, required this.examId});

  final String examId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final examAsync = ref.watch(examMarksExamProvider(examId));
    final marksAsync = ref.watch(examMarksListProvider(examId));
    final approvalRequired = ref.watch(examApprovalRequiredProvider);

    return Scaffold(
      appBar: AppBar(
        title: examAsync.when(
          data: (exam) => Text(exam?.title ?? 'Marks entry'),
          loading: () => const Text('Marks entry'),
          error: (_, __) => const Text('Marks entry'),
        ),
        actions: [
          examAsync.maybeWhen(
            data: (exam) {
              if (exam == null) return const SizedBox.shrink();
              return marksAsync.maybeWhen(
                data: (marks) => IconButton(
                  key: QaTestKeys.examMarksExportButton(examId),
                  tooltip: 'Export marks',
                  onPressed: marks.isEmpty
                      ? null
                      : () async {
                          final service = ref.read(
                            aksharaReportExportServiceProvider,
                          );
                          final rows = [
                            for (final mark in marks)
                              MapEntry(
                                mark.rollNo,
                                '${mark.studentName} · ${mark.marksObtained ?? '—'}/${exam.maxMarks}',
                              ),
                          ];
                          await service.shareTabularCsv(
                            filename: '${examId}_marks.csv',
                            reportTitle: '${exam.title} marks',
                            rows: rows,
                          );
                        },
                  icon: const Icon(Icons.download_outlined),
                ),
                orElse: () => const SizedBox.shrink(),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: examAsync.when(
        loading: () => const AksharaLoadingState(semanticLabel: 'Loading exam'),
        error: (_, __) => AksharaErrorState(
          message: 'Unable to load exam session.',
          onRetry: () => refreshExamAdminList(ref),
        ),
        data: (exam) {
          if (exam == null) {
            return const AksharaEmptyState(
              message: 'Exam session not found.',
              icon: Icons.assignment_outlined,
            );
          }
          return marksAsync.when(
            loading: () => const AksharaLoadingState(
              semanticLabel: 'Loading marks roster',
            ),
            error: (_, __) => AksharaErrorState(
              message: 'Unable to load marks roster.',
              onRetry: () => refreshExamAdminList(ref),
            ),
            data: (marks) => _MarksEntryBody(
              exam: exam,
              marks: marks,
              approvalRequired: approvalRequired,
            ),
          );
        },
      ),
    );
  }
}

class _MarksEntryBody extends ConsumerWidget {
  const _MarksEntryBody({
    required this.exam,
    required this.marks,
    required this.approvalRequired,
  });

  final ExamSession exam;
  final List<ExamMarkRecord> marks;
  final bool approvalRequired;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = context.aksharaText;
    final entered = marks.where((m) => m.marksObtained != null).length;
    final canEdit = exam.phase == ExamLifecyclePhase.marksEntry ||
        exam.phase == ExamLifecyclePhase.scheduled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${exam.classLabel} · ${exam.subject}',
                      style: text.titleMedium,
                    ),
                  ),
                  AksharaStatusChip(
                    label: examPhaseLabel(exam.phase),
                    tone: KpiAccent.primary,
                  ),
                ],
              ),
              Text(
                '$entered / ${marks.length} marks entered · Max ${exam.maxMarks}',
                style: text.bodyMedium,
              ),
              if (exam.rejectionComment != null) ...[
                const SizedBox(height: AksharaSpacing.s2),
                AksharaWarningBanner(
                  message:
                      'Principal rejected publication: ${exam.rejectionComment}',
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: AksharaSpacing.s4),
            itemCount: marks.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: AksharaSpacing.s2),
            itemBuilder: (context, index) =>
                _MarkEntryRow(mark: marks[index], exam: exam, canEdit: canEdit),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          child: Wrap(
            spacing: AksharaSpacing.s2,
            runSpacing: AksharaSpacing.s2,
            children: [
              if (exam.phase == ExamLifecyclePhase.marksEntry ||
                  exam.phase == ExamLifecyclePhase.processed)
                AksharaManageAction(
                  permission: Permission.manageExams,
                  auditRoute: '/school/exam-administration',
                  child: OutlinedButton(
                    key: QaTestKeys.examAdminProcessResultsButton(exam.id),
                    onPressed: () => _processResults(context, ref),
                    child: const Text('Process results'),
                  ),
                ),
              if (exam.phase == ExamLifecyclePhase.processed &&
                  !exam.coordinatorVerified)
                AksharaViewAction(
                  permission: Permission.verifyExamResults,
                  child: FilledButton.tonal(
                    key: QaTestKeys.examAdminVerifyCoordinatorButton(exam.id),
                    onPressed: () => _verifyCoordinator(context, ref),
                    child: const Text('Verify & forward to principal'),
                  ),
                ),
              if (approvalRequired &&
                  exam.phase == ExamLifecyclePhase.processed &&
                  exam.coordinatorVerified)
                AksharaViewAction(
                  permission: Permission.submitExamResults,
                  child: FilledButton(
                    key: QaTestKeys.examAdminSubmitApprovalButton(exam.id),
                    onPressed: () => _submitForApproval(context, ref),
                    child: const Text('Submit for principal approval'),
                  ),
                ),
              if (approvalRequired &&
                  (exam.phase == ExamLifecyclePhase.processed ||
                      exam.phase == ExamLifecyclePhase.marksEntry) &&
                  !exam.coordinatorVerified)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s2),
                  child: Text(
                    'Coordinator verification required before principal approval.',
                  ),
                ),
              if (!approvalRequired &&
                  (exam.phase == ExamLifecyclePhase.processed ||
                      exam.phase == ExamLifecyclePhase.marksEntry))
                AksharaViewAction(
                  permission: Permission.publishExamResults,
                  child: FilledButton(
                    onPressed: () => _publishDirect(context, ref),
                    child: const Text('Publish results'),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _verifyCoordinator(BuildContext context, WidgetRef ref) async {
    try {
      await ref
          .read(examMarksMutationProvider.notifier)
          .verifyCoordinatorResults(exam.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Results verified — ready for principal approval'),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }

  Future<void> _processResults(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(examMarksMutationProvider.notifier).processResults(exam.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Results processed — ready for submission')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }

  Future<void> _submitForApproval(BuildContext context, WidgetRef ref) async {
    try {
      final approvalId = await ref
          .read(examMarksMutationProvider.notifier)
          .submitForApproval(exam.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Submitted for principal approval ($approvalId)'),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }

  Future<void> _publishDirect(BuildContext context, WidgetRef ref) async {
    try {
      final count =
          await ref.read(examMarksMutationProvider.notifier).publishDirect(exam.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Published $count student results')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }
}

class _MarkEntryRow extends ConsumerStatefulWidget {
  const _MarkEntryRow({
    required this.mark,
    required this.exam,
    required this.canEdit,
  });

  final ExamMarkRecord mark;
  final ExamSession exam;
  final bool canEdit;

  @override
  ConsumerState<_MarkEntryRow> createState() => _MarkEntryRowState();
}

class _MarkEntryRowState extends ConsumerState<_MarkEntryRow> {
  late final TextEditingController _controller;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.mark.marksObtained?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _MarkEntryRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final current = widget.mark.marksObtained?.toString() ?? '';
    if (_controller.text != current && !_saving) {
      _controller.text = current;
    }
  }

  Future<void> _save() async {
    final parsed = int.tryParse(_controller.text.trim());
    if (parsed == null) return;
    if (parsed < 0 || parsed > widget.exam.maxMarks) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Marks must be between 0 and ${widget.exam.maxMarks}'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(examMarksMutationProvider.notifier).updateMark(
            markEntryId: widget.mark.id,
            marksObtained: parsed,
          );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openLeadershipRemarkDialog() async {
    var text = leadershipExamRemarkText(
          ref,
          widget.exam.id,
          widget.mark.sisStudentId,
        ) ??
        '';
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Leadership remark · ${widget.mark.studentName}'),
        content: TextFormField(
          key: QaTestKeys.examLeadershipRemarkField,
          initialValue: text,
          maxLines: 3,
          onChanged: (value) => text = value,
          decoration: const InputDecoration(
            hintText: 'Principal / vice-principal remark for this student',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: QaTestKeys.examLeadershipRemarkSaveButton,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved != true) return;
    try {
      await saveLeadershipExamRemark(
        ref,
        examId: widget.exam.id,
        sisStudentId: widget.mark.sisStudentId,
        text: text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Remark saved for ${widget.mark.studentName}')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    final canRemark = ref.watch(canAuthorLeadershipExamRemarkProvider);

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(AksharaSpacing.s3),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: Text(widget.mark.rollNo, style: text.labelLarge),
            ),
            Expanded(
              child: Text(widget.mark.studentName, style: text.bodyLarge),
            ),
            if (canRemark)
              IconButton(
                key: QaTestKeys.examLeadershipRemarkButton(widget.mark.id),
                tooltip: 'Leadership remark',
                icon: const Icon(Icons.rate_review_outlined),
                onPressed: _openLeadershipRemarkDialog,
              ),
            SizedBox(
              width: 88,
              child: TextField(
                key: QaTestKeys.examAdminMarkField(widget.mark.id),
                controller: _controller,
                enabled: widget.canEdit && !widget.mark.published,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Marks',
                  isDense: true,
                  suffixText: '/${widget.exam.maxMarks}',
                ),
                onSubmitted: (_) => _save(),
              ),
            ),
            const SizedBox(width: AksharaSpacing.s2),
            AksharaViewAction(
              permission: Permission.manageExamMarks,
              child: IconButton(
                key: QaTestKeys.examAdminMarkSaveButton(widget.mark.id),
                onPressed:
                    widget.canEdit && !widget.mark.published ? _save : null,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                tooltip: 'Save mark',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
