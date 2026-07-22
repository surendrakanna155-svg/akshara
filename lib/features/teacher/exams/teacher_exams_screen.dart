import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/exam_approval_config.dart';
import '../../../core/exams/exam_administration_store.dart';
import '../../../core/reports/akshara_report_export_service.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../reports/teacher_report_exporters.dart';
import '../reports/teacher_report_share_sheet.dart';
import '../../../shared/marks_grid/marks_grid.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/premium_tokens.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../../theme/typography.dart';
import 'exam_models.dart';
import 'teacher_exams_provider.dart';
import '../communication/teacher_teaching_context_provider.dart';
import '../../academics/exam_admin/exam_administration_provider.dart';
import '../teacher_mutations_provider.dart';
import '../../../theme/breakpoints.dart';

/// Teacher exams — TA-05.
class TeacherExamsScreen extends ConsumerWidget {
  const TeacherExamsScreen({super.key, this.onNotificationsTap});

  final VoidCallback? onNotificationsTap;

  static const double _tabletBreakpoint = AksharaBreakpoints.tabletMinWidth;
  static const double _tabletMaxContentWidth =
      AksharaBreakpoints.compactContentMaxWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(teacherExamsProvider);
    final section = ref.watch(teacherExamSectionProvider);
    final isLoading = ref.watch(teacherExamsLoadingProvider);
    final hasError = ref.watch(teacherExamsErrorProvider);
    final teaching = ref.watch(resolvedTeacherTeachingContextProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AksharaAppBar(
        titleText: 'Exams',
        subtitle: teaching.appBarSubtitle,
        unreadNotifications: data.unreadNotifications,
        trailingPadding: true,
        onNotificationsTap: onNotificationsTap,
        additionalActions: [
          // TCH-3 — export my-class marks summary (entered/total/pending +
          // status) as CSV/PDF on the shared XCT-1 grid pipeline.
          IconButton(
            key: QaTestKeys.teacherMarksSummaryExportButton,
            tooltip: 'Export marks summary',
            onPressed: () {
              final progress =
                  ExamAdministrationStore.instance.marksEntryProgress();
              final exporters = TeacherReportExporters(
                ref.read(aksharaReportExportServiceProvider),
              );
              showTeacherExportSheet(
                context,
                title: 'Export marks summary',
                onCsv: () => exporters.shareMarksSummaryCsv(progress),
                onPdf: () => exporters.shareMarksSummaryPdf(progress),
              );
            },
            icon: const Icon(Icons.ios_share_outlined),
          ),
        ],
      ),
      // DS V2 P4 — premium persona canvas behind the exams content.
      body: AksharaPremiumBackground(
        showMotif: false,
        child: isLoading
            ? const AksharaLoadingState()
            : hasError
                ? AksharaErrorState(
                    message: 'Unable to load exam data.',
                    onRetry: () => ref
                        .read(teacherExamsErrorProvider.notifier)
                        .state = false,
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
                          child: RefreshIndicator(
                            onRefresh: () async => ref
                                .invalidate(teacherUpcomingExamsFutureProvider),
                            child: SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: EdgeInsets.fromLTRB(
                                pad,
                                AksharaSpacing.s4,
                                pad,
                                AksharaSpacing.s6,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _ExamsSummaryCard(
                                    classAveragePercent:
                                        data.classAveragePercent,
                                    upcomingCount: data.upcomingExams.length,
                                    pendingMarksCount: data.markEntries
                                        .where((m) => m.marksObtained == null)
                                        .length,
                                  ),
                                  const SizedBox(height: AksharaSpacing.s4),
                                  Semantics(
                                    label: 'Exam section selector',
                                    child: SegmentedButton<TeacherExamSection>(
                                      segments: [
                                        for (final s
                                            in TeacherExamSection.values)
                                          ButtonSegment(
                                            value: s,
                                            label: Text(s.label),
                                          ),
                                      ],
                                      selected: {section},
                                      showSelectedIcon: false,
                                      onSelectionChanged: (v) => ref
                                          .read(teacherExamSectionProvider
                                              .notifier)
                                          .state = v.first,
                                    ),
                                  ),
                                  const SizedBox(height: AksharaSpacing.s4),
                                  switch (section) {
                                    TeacherExamSection.upcoming =>
                                      _UpcomingList(exams: data.upcomingExams),
                                    TeacherExamSection.marksEntry =>
                                      _MarksEntryPanel(
                                          entries: data.markEntries),
                                    TeacherExamSection.results => _ResultsPanel(
                                        classAveragePercent:
                                            data.classAveragePercent,
                                      ),
                                  },
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

/// TA-05 exams summary — DS V2 Phase 4 flagship: the class-average % as a
/// signature persona-accent progress **ring**, with upcoming-exam and pending-
/// marks counts as adjacent stats. Same three metrics as the old three-up KPI
/// strip.
class _ExamsSummaryCard extends StatelessWidget {
  const _ExamsSummaryCard({
    required this.classAveragePercent,
    required this.upcomingCount,
    required this.pendingMarksCount,
  });

  final int classAveragePercent;
  final int upcomingCount;
  final int pendingMarksCount;

  @override
  Widget build(BuildContext context) {
    final premium = context.premium;
    final text = context.aksharaText;
    final colors = context.colors;
    final ext = context.akshara;

    return Semantics(
      container: true,
      label: 'Class average $classAveragePercent percent, '
          '$upcomingCount upcoming exams, $pendingMarksCount pending marks',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: premium.premiumSurface,
          borderRadius: BorderRadius.circular(AksharaRadius.xl),
          border: Border.all(color: premium.premiumBorder),
          boxShadow: premium.softShadow,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AksharaProgressRing(
                value: classAveragePercent / 100.0,
                size: 92,
                strokeWidth: 9,
                color: premium.brandStart,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$classAveragePercent%',
                      style: text.titleMedium.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        height: 1.0,
                      ),
                    ),
                    Text(
                      'Class avg',
                      style: text.labelSmall.copyWith(
                        color: colors.onSurfaceVariant,
                        fontSize: 10,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AksharaSpacing.s5),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Stat(
                      value: '$upcomingCount',
                      label: 'Upcoming',
                      color: colors.primary,
                    ),
                    const SizedBox(height: AksharaSpacing.s3),
                    _Stat(
                      value: '$pendingMarksCount',
                      label: 'Pending marks',
                      color: ext.warning,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: text.titleLarge
              .copyWith(
                color: color,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                height: 1.05,
              )
              .tabularFigures,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          label,
          style: text.bodySmall.copyWith(color: colors.onSurfaceVariant),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
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
    final coordinatorVerified =
        ref.watch(teacherExamCoordinatorVerifiedProvider);
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
          onAction: () => ref.read(teacherExamSectionProvider.notifier).state =
              TeacherExamSection.marksEntry,
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
          if (i < exams.length - 1) const SizedBox(height: AksharaSpacing.s2),
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
    final options =
        optionsAsync.valueOrNull ?? const <TeacherExamSessionOption>[];
    // Hydrate backend-persisted remarks for the active exam into the local cache.
    if (activeExamId != null) {
      ref.watch(examRemarksHydrationProvider(activeExamId));
    }

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
  // P2-UX-2 §2.2 — one focus node per row so Enter advances down the column,
  // matching the exam-admin grid's keyboard-first ergonomics.
  final Map<String, FocusNode> _focusNodes = {};

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(ExamMarkEntry entry) {
    return _controllers.putIfAbsent(
      entry.id,
      () => TextEditingController(
        text: entry.marksObtained?.toString() ?? '',
      )..addListener(_onFieldChanged),
    );
  }

  FocusNode _focusFor(String id) => _focusNodes.putIfAbsent(id, FocusNode.new);

  // Refresh the per-cell dots + column stats + Save-all visibility as marks are
  // keyed (a small roster — a plain setState is cheap and keeps the grid live).
  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  /// The spreadsheet "unsaved cell" state for this row: saved when the typed
  /// value matches the persisted mark, unsaved while it differs, empty when
  /// nothing is typed yet.
  MarksCellState _cellState(ExamMarkEntry entry) {
    final raw = _controllerFor(entry).text.trim();
    if (raw.isEmpty) {
      return entry.marksObtained == null
          ? MarksCellState.empty
          : MarksCellState.unsaved;
    }
    final parsed = int.tryParse(raw);
    if (parsed == null) return MarksCellState.unsaved;
    return parsed == entry.marksObtained
        ? MarksCellState.saved
        : MarksCellState.unsaved;
  }

  bool _isDirty(ExamMarkEntry entry) =>
      _cellState(entry) == MarksCellState.unsaved;

  void _focusNextRow(int fromIndex) {
    final next = fromIndex + 1;
    if (next < widget.entries.length) {
      _focusFor(widget.entries[next].id).requestFocus();
    } else {
      FocusScope.of(context).unfocus();
    }
  }

  String? _saveOne(ExamMarkEntry entry) {
    return saveTeacherExamMarkFromInput(
      ref,
      entry: entry,
      raw: _controllerFor(entry).text,
    );
  }

  /// P2-UX-2 §2.2 — save every changed row in one action, reusing the SAME
  /// per-row save path (validation + updateExamMark); no new backend surface.
  void _saveAll() {
    var saved = 0;
    final errors = <String>[];
    for (final entry in widget.entries) {
      if (!_isDirty(entry)) continue;
      final error = _saveOne(entry);
      if (error != null) {
        errors.add('${entry.studentName}: $error');
      } else {
        saved++;
      }
    }
    if (!mounted) return;
    final message = errors.isEmpty
        ? '$saved saved'
        : '$saved saved, ${errors.length} need attention (${errors.first})';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
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

    final entries = widget.entries;
    final entered = entries.where((e) => e.marksObtained != null).length;
    final maxMarks = entries.first.maxMarks;
    final scored = entries.where((e) => e.marksObtained != null).toList();
    final avg = scored.isEmpty
        ? null
        : scored
                .map((e) => e.maxMarks == 0
                    ? 0.0
                    : (e.marksObtained! / e.maxMarks) * 100)
                .reduce((a, b) => a + b) /
            scored.length;
    final dirtyCount = entries.where(_isDirty).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // P2-UX-2 §2.2 — Save-all changed rows in one action (dirty rows only).
        if (dirtyCount > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: AksharaSpacing.s2),
            child: Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                key: QaTestKeys.teacherExamSaveAllButton,
                onPressed: _saveAll,
                icon: const Icon(Icons.done_all, size: 18),
                label: Text('Save all ($dirtyCount)'),
              ),
            ),
          ),
        for (var index = 0; index < entries.length; index++)
          _buildRow(context, entries[index], index, isClassTeacher, examId),
        const SizedBox(height: AksharaSpacing.s3),
        // Shared inline column-stats footer (same component the admin grid uses).
        MarksColumnStats(
          key: QaTestKeys.marksColumnStats,
          entered: entered,
          total: entries.length,
          averagePercent: avg,
          maxMarks: maxMarks,
        ),
      ],
    );
  }

  Widget _buildRow(
    BuildContext context,
    ExamMarkEntry entry,
    int index,
    bool isClassTeacher,
    String? examId,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AksharaSpacing.s1),
      child: Row(
        children: [
          // Shared per-cell save-state dot.
          MarksCellSaveDot(state: _cellState(entry)),
          const SizedBox(width: AksharaSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.studentName, style: context.aksharaText.bodyMedium),
                Text(
                  'Roll ${entry.rollNo}',
                  style: context.aksharaText.bodySmall
                      .copyWith(color: context.colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (isClassTeacher && examId != null)
            IconButton(
              key: QaTestKeys.teacherExamRemarkButton(entry.id),
              tooltip: 'Remark',
              icon: const Icon(Icons.rate_review_outlined),
              onPressed: () => _openRemarkDialog(context, examId, entry),
            ),
          // Shared locked number-pad field, with Enter advancing down the column.
          MarksEntryField(
            fieldKey: QaTestKeys.teacherExamMarkField(entry.id),
            controller: _controllerFor(entry),
            maxMarks: entry.maxMarks,
            focusNode: _focusFor(entry.id),
            width: 96,
            onSubmitted: () {
              final error = _saveOne(entry);
              if (error != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(error)),
                );
              } else {
                _focusNextRow(index);
              }
            },
          ),
          IconButton(
            key: QaTestKeys.teacherExamMarkSaveButton(entry.id),
            tooltip: 'Save mark',
            onPressed: () {
              final error = _saveOne(entry);
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
    );
  }
}
