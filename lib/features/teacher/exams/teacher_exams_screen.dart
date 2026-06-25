import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/exam_approval_config.dart';
import '../../../core/exams/exam_administration_store.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import 'exam_models.dart';
import 'teacher_exams_provider.dart';
import '../teacher_mutations_provider.dart';
import '../../../theme/breakpoints.dart';

/// Teacher exams — TA-05.
class TeacherExamsScreen extends ConsumerWidget {
  const TeacherExamsScreen({super.key, this.onNotificationsTap});

  final VoidCallback? onNotificationsTap;

  static const double _tabletBreakpoint = AksharaBreakpoints.tabletMinWidth;
  static const double _tabletMaxContentWidth = AksharaBreakpoints.compactContentMaxWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(teacherExamsProvider);
    final section = ref.watch(teacherExamSectionProvider);
    final isLoading = ref.watch(teacherExamsLoadingProvider);
    final hasError = ref.watch(teacherExamsErrorProvider);

    return Scaffold(
      backgroundColor: context.colors.surfaceContainerLow,
      appBar: AksharaAppBar(
        titleText: 'Exams',
        subtitle: 'Priya Sharma · Mathematics',
        unreadNotifications: data.unreadNotifications,
        trailingPadding: true,
        onNotificationsTap: onNotificationsTap,
      ),
      body: isLoading
          ? const AksharaLoadingState()
          : hasError
              ? AksharaErrorState(
                  message: 'Unable to load exam data.',
                  onRetry: () =>
                      ref.read(teacherExamsErrorProvider.notifier).state = false,
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final isTablet =
                        constraints.maxWidth >= _tabletBreakpoint;
                    final pad = isTablet
                        ? AksharaSpacing.tabletMargin
                        : AksharaSpacing.mobileMargin;

                    return Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: isTablet
                              ? _tabletMaxContentWidth
                              : double.infinity,
                        ),
                        child: SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(
                            pad,
                            AksharaSpacing.s4,
                            pad,
                            AksharaSpacing.s6,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                height: 88,
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: AksharaKpiCard(
                                        value: '${data.upcomingExams.length}',
                                        subtitle: 'Upcoming',
                                        accent: KpiAccent.primary,
                                      ),
                                    ),
                                    const SizedBox(width: AksharaSpacing.s2),
                                    Expanded(
                                      child: AksharaKpiCard(
                                        value: '${data.classAveragePercent}%',
                                        subtitle: 'Class avg',
                                        accent: KpiAccent.success,
                                      ),
                                    ),
                                    const SizedBox(width: AksharaSpacing.s2),
                                    Expanded(
                                      child: AksharaKpiCard(
                                        value:
                                            '${data.markEntries.where((m) => m.marksObtained == null).length}',
                                        subtitle: 'Pending marks',
                                        accent: KpiAccent.warning,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AksharaSpacing.s4),
                              Semantics(
                                label: 'Exam section selector',
                                child: SegmentedButton<TeacherExamSection>(
                                  segments: [
                                    for (final s in TeacherExamSection.values)
                                      ButtonSegment(
                                        value: s,
                                        label: Text(s.label),
                                      ),
                                  ],
                                  selected: {section},
                                  showSelectedIcon: false,
                                  onSelectionChanged: (v) => ref
                                      .read(teacherExamSectionProvider.notifier)
                                      .state = v.first,
                                ),
                              ),
                              const SizedBox(height: AksharaSpacing.s4),
                              switch (section) {
                                TeacherExamSection.upcoming =>
                                  _UpcomingList(exams: data.upcomingExams),
                                TeacherExamSection.marksEntry =>
                                  _MarksEntryPanel(entries: data.markEntries),
                                TeacherExamSection.results => _ResultsPanel(
                                    classAveragePercent:
                                        data.classAveragePercent,
                                  ),
                              },
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class _ResultsPanel extends ConsumerWidget {
  const _ResultsPanel({required this.classAveragePercent});

  final int classAveragePercent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final examId = ref.watch(teacherActiveExamIdProvider);
    final approvalRequired = ref.watch(examApprovalRequiredProvider);
    final pendingApproval = ref.watch(teacherExamPendingApprovalProvider);
    final rejectionComment = ref.watch(teacherExamRejectionCommentProvider);
    final coordinatorVerified = ref.watch(teacherExamCoordinatorVerifiedProvider);
    final examPhase = ref.watch(teacherExamPhaseProvider);
    final processState = ref.watch(processTeacherExamResultsProvider);
    final publishState = ref.watch(publishTeacherExamResultsProvider);
    final submitState = ref.watch(submitTeacherExamResultsForApprovalProvider);
    final isLoading = processState.isLoading ||
        publishState.isLoading ||
        submitState.isLoading;
    final isProcessed = examPhase == ExamLifecyclePhase.processed ||
        examPhase == ExamLifecyclePhase.published;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AksharaInsightCard(
          message:
              'Class average is $classAveragePercent% for Unit Test — Mathematics.',
          actionLabel: 'Review marks',
          onAction: () => ref
              .read(teacherExamSectionProvider.notifier)
              .state = TeacherExamSection.marksEntry,
        ),
        if (rejectionComment != null && rejectionComment.isNotEmpty) ...[
          const SizedBox(height: AksharaSpacing.s3),
          Material(
            color: context.colors.errorContainer,
            borderRadius: AksharaRadius.card,
            child: Padding(
              padding: const EdgeInsets.all(AksharaSpacing.s3),
              child: Text(
                'Principal feedback: $rejectionComment',
                style: context.aksharaText.bodyMedium.copyWith(
                  color: context.colors.onErrorContainer,
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: AksharaSpacing.s3),
        if (approvalRequired) ...[
          if (!isProcessed)
            FilledButton.tonalIcon(
              key: QaTestKeys.examSubmitVerificationButton,
              onPressed: examId == null || isLoading
                  ? null
                  : () async {
                      final result =
                          await processExamResultsForVerification(ref, examId);
                      if (!context.mounted || result == null) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Submitted for coordinator verification: ${result.examTitle}',
                          ),
                        ),
                      );
                    },
              icon: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.fact_check_outlined),
              label: const Text('Submit for verification'),
            ),
          if (isProcessed && !coordinatorVerified)
            const Padding(
              padding: EdgeInsets.only(bottom: AksharaSpacing.s2),
              child: Text(
                'Awaiting exam coordinator verification before principal approval.',
              ),
            ),
          if (isProcessed && coordinatorVerified)
            FilledButton.icon(
              key: QaTestKeys.examSubmitApprovalButton,
              onPressed: examId == null ||
                      isLoading ||
                      pendingApproval.asData?.value == true
                  ? null
                  : () async {
                      final result =
                          await submitExamResultsForApproval(ref, examId);
                      if (!context.mounted || result == null) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Submitted for approval: ${result.title}',
                          ),
                        ),
                      );
                    },
              icon: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_outlined),
              label: Text(
                pendingApproval.asData?.value == true
                    ? 'Pending principal approval'
                    : 'Submit for principal approval',
              ),
            ),
        ] else
          FilledButton.icon(
            onPressed: examId == null || isLoading
                ? null
                : () async {
                    final result = await publishExamResults(ref, examId);
                    if (!context.mounted || result == null) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Published ${result.publishedCount} results to student and parent apps.',
                        ),
                      ),
                    );
                  },
            icon: isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.publish_outlined),
            label: const Text('Publish results'),
          ),
      ],
    );
  }
}

class _UpcomingList extends ConsumerWidget {
  const _UpcomingList({required this.exams});
  final List<TeacherUpcomingExam> exams;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (exams.isEmpty) {
      return const AksharaEmptyState(
        message: 'No upcoming exams.',
        compact: true,
      );
    }

    final colors = context.colors;
    final text = context.aksharaText;

    return Column(
      children: [
        for (var i = 0; i < exams.length; i++) ...[
          Material(
            color: colors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: AksharaRadius.card,
              side: BorderSide(color: colors.outlineVariant),
            ),
            child: ListTile(
              title: Text(exams[i].title, style: text.titleSmall),
              subtitle: Text(
                '${exams[i].classLabel} · ${exams[i].dateLabel} · Max ${exams[i].maxMarks}',
              ),
              trailing: exams[i].canEnterMarks
                  ? const Icon(Icons.edit_note_outlined)
                  : null,
              onTap: exams[i].canEnterMarks
                  ? () {
                      ref.read(teacherSelectedExamIdProvider.notifier).state =
                          exams[i].id;
                      resetTeacherExamMarksOverride(ref);
                      ref.read(teacherExamSectionProvider.notifier).state =
                          TeacherExamSection.marksEntry;
                    }
                  : null,
            ),
          ),
          if (i < exams.length - 1)
            const SizedBox(height: AksharaSpacing.s2),
        ],
      ],
    );
  }
}

class _MarksEntryPanel extends ConsumerWidget {
  const _MarksEntryPanel({required this.entries});
  final List<ExamMarkEntry> entries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final optionsAsync = ref.watch(teacherMarksExamOptionsProvider);
    final activeExamId = ref.watch(teacherActiveExamIdProvider);
    final activeExam = ref.watch(teacherActiveExamProvider);
    final options = optionsAsync.valueOrNull ?? const <TeacherExamSessionOption>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (activeExam != null) _ExamContextHeader(exam: activeExam),
        if (options.length > 1) ...[
          const SizedBox(height: AksharaSpacing.s3),
          DropdownButtonFormField<String>(
            key: QaTestKeys.teacherExamSelector,
            initialValue: activeExamId,
            decoration: const InputDecoration(
              labelText: 'Exam session',
              isDense: true,
            ),
            items: [
              for (final exam in options)
                DropdownMenuItem(
                  value: exam.id,
                  child: Text('${exam.classLabel} · ${exam.title}'),
                ),
            ],
            onChanged: (value) {
              resetTeacherExamMarksOverride(ref);
              ref.read(teacherSelectedExamIdProvider.notifier).state = value;
            },
          ),
          const SizedBox(height: AksharaSpacing.s3),
        ] else if (activeExam != null)
          const SizedBox(height: AksharaSpacing.s3),
        _MarksEntryList(entries: entries),
      ],
    );
  }
}

class _ExamContextHeader extends StatelessWidget {
  const _ExamContextHeader({required this.exam});

  final TeacherExamSessionOption exam;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    final colors = context.colors;

    return Material(
      color: colors.primaryContainer,
      borderRadius: AksharaRadius.card,
      child: Padding(
        padding: const EdgeInsets.all(AksharaSpacing.s3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(exam.title, style: text.titleSmall),
            const SizedBox(height: AksharaSpacing.s1),
            Text(
              '${exam.classLabel} · ${exam.subject} · ${exam.termLabel}',
              style: text.bodySmall.copyWith(color: colors.onPrimaryContainer),
            ),
            Text(
              '${exam.dateLabel} · Max ${exam.maxMarks}',
              style: text.bodySmall.copyWith(color: colors.onPrimaryContainer),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarksEntryList extends ConsumerStatefulWidget {
  const _MarksEntryList({required this.entries});
  final List<ExamMarkEntry> entries;

  @override
  ConsumerState<_MarksEntryList> createState() => _MarksEntryListState();
}

class _MarksEntryListState extends ConsumerState<_MarksEntryList> {
  final Map<String, TextEditingController> _controllers = {};

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(ExamMarkEntry entry) {
    return _controllers.putIfAbsent(
      entry.id,
      () => TextEditingController(
        text: entry.marksObtained?.toString() ?? '',
      ),
    );
  }

  Future<void> _openRemarkDialog(
    BuildContext context,
    String examId,
    ExamMarkEntry entry,
  ) async {
    var text = teacherExamRemarkText(ref, examId, entry.sisStudentId) ?? '';
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Remark · ${entry.studentName}'),
        content: TextFormField(
          key: QaTestKeys.teacherExamRemarkField,
          initialValue: text,
          maxLines: 3,
          onChanged: (value) => text = value,
          decoration: const InputDecoration(
            hintText: 'Write a remark for this student',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: QaTestKeys.teacherExamRemarkSaveButton,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved == true) {
      await saveTeacherExamRemark(
        ref,
        examId: examId,
        sisStudentId: entry.sisStudentId,
        text: text,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Remark saved for ${entry.studentName}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.entries.isEmpty) {
      return const AksharaEmptyState(
        message: 'No students for marks entry.',
        compact: true,
      );
    }

    final isClassTeacher =
        ref.watch(teacherIsClassTeacherForActiveExamProvider);
    final examId = ref.watch(teacherActiveExamIdProvider);

    return Column(
      children: [
        for (final entry in widget.entries)
          ListTile(
            title: Text(entry.studentName),
            subtitle: Text('Roll ${entry.rollNo}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isClassTeacher && examId != null)
                  IconButton(
                    key: QaTestKeys.teacherExamRemarkButton(entry.id),
                    tooltip: 'Remark',
                    icon: const Icon(Icons.rate_review_outlined),
                    onPressed: () =>
                        _openRemarkDialog(context, examId, entry),
                  ),
                SizedBox(
                  width: 72,
                  child: TextField(
                    key: QaTestKeys.teacherExamMarkField(entry.id),
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: '/${entry.maxMarks}',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    controller: _controllerFor(entry),
                  ),
                ),
                IconButton(
                  key: QaTestKeys.teacherExamMarkSaveButton(entry.id),
                  tooltip: 'Save mark',
                  onPressed: () {
                    final error = saveTeacherExamMarkFromInput(
                      ref,
                      entry: entry,
                      raw: _controllerFor(entry).text,
                    );
                    if (error != null && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(error)),
                      );
                    }
                  },
                  icon: const Icon(Icons.save_outlined),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
