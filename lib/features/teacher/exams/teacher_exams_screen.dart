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
import '../../academics/exam_admin/exam_marks_entry_provider.dart';
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
    // Honest state: null until at least one mark is scored — never a measured 0%.
    final classAveragePercent = ref.watch(teacherClassAveragePercentProvider);
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
          // E2E-012 — the export is built from the LIVE marks-entry progress
          // read (`examMarksEntryProgressProvider` → the repository), not from
          // `ExamAdministrationStore.instance.marksEntryProgress()`, which calls
          // `ensureSeeded()` and in a release build returns the seeded demo exam
          // (`exam_math_8a`, "Unit Test — Mathematics", mock roster). The file
          // leaves the app, so it must describe exams that exist. With no live
          // rows there is nothing to export and the action says so.
          IconButton(
            key: QaTestKeys.teacherMarksSummaryExportButton,
            tooltip: 'Export marks summary',
            onPressed: () {
              final progress =
                  ref.read(examMarksEntryProgressProvider).valueOrNull;
              if (progress == null || progress.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'No marks-entry data available to export yet.',
                    ),
                  ),
                );
                return;
              }
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
                            // PERF (RC): a sliver scroll view, not a
                            // SingleChildScrollView + Column. The marks-entry
                            // roster contributes a lazily-built SliverList, so a
                            // 40–60 student class no longer mounts 40–60 live
                            // TextFields up front — rows build and recycle with
                            // the viewport. One scroll view, so there is no
                            // nested/double scroll and no unbounded height.
                            child: CustomScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              slivers: [
                                SliverPadding(
                                  padding: EdgeInsets.fromLTRB(
                                    pad,
                                    AksharaSpacing.s4,
                                    pad,
                                    AksharaSpacing.s6,
                                  ),
                                  sliver: SliverMainAxisGroup(
                                    slivers: [
                                      SliverToBoxAdapter(
                                        child: _ExamsSummaryCard(
                                          classAveragePercent:
                                              classAveragePercent,
                                          upcomingCount:
                                              data.upcomingExams.length,
                                          pendingMarksCount: data.markEntries
                                              .where(
                                                  (m) => m.marksObtained == null)
                                              .length,
                                        ),
                                      ),
                                      const SliverToBoxAdapter(
                                        child:
                                            SizedBox(height: AksharaSpacing.s4),
                                      ),
                                      SliverToBoxAdapter(
                                        child: Semantics(
                                          label: 'Exam section selector',
                                          child: SegmentedButton<
                                              TeacherExamSection>(
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
                                      ),
                                      const SliverToBoxAdapter(
                                        child:
                                            SizedBox(height: AksharaSpacing.s4),
                                      ),
                                      switch (section) {
                                        TeacherExamSection.upcoming =>
                                          SliverToBoxAdapter(
                                            child: _UpcomingList(
                                                exams: data.upcomingExams),
                                          ),
                                        TeacherExamSection.marksEntry =>
                                          _MarksEntryPanel(
                                              entries: data.markEntries),
                                        TeacherExamSection.results =>
                                          SliverToBoxAdapter(
                                            child: _ResultsPanel(
                                              classAveragePercent:
                                                  classAveragePercent,
                                            ),
                                          ),
                                      },
                                    ],
                                  ),
                                ),
                              ],
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
///
/// [classAveragePercent] is null when NO mark has been scored yet. Honest state:
/// the ring then reads as the app's standard unknown placeholder ("—") over an
/// empty track, never as a measured `0%`.
class _ExamsSummaryCard extends StatelessWidget {
  const _ExamsSummaryCard({
    required this.classAveragePercent,
    required this.upcomingCount,
    required this.pendingMarksCount,
  });

  final int? classAveragePercent;
  final int upcomingCount;
  final int pendingMarksCount;

  @override
  Widget build(BuildContext context) {
    final premium = context.premium;
    final text = context.aksharaText;
    final colors = context.colors;
    final ext = context.akshara;
    final average = classAveragePercent;
    final averageSemantics = average == null
        ? 'Class average not measured yet'
        : 'Class average $average percent';

    return Semantics(
      container: true,
      label: '$averageSemantics, '
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
                // Unknown → 0 sweep, i.e. the bare track: the ring shows no
                // progress rather than claiming a measured zero.
                value: (average ?? 0) / 100.0,
                size: 92,
                strokeWidth: 9,
                color: premium.brandStart,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      average == null ? '—' : '$average%',
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

  /// Null when no mark has been scored yet — there is no average to report.
  final int? classAveragePercent;

  /// The active exam as a human label ("Unit Test — Mathematics"), or null when
  /// the exam context genuinely is not loaded. NEVER a hardcoded guess: every
  /// teacher of every subject used to be told "Unit Test — Mathematics".
  ///
  /// Seeded/administered titles usually already carry the subject, so the
  /// subject is appended only when the title does not already name it.
  static String? _examLabel(TeacherExamSessionOption? exam) {
    if (exam == null) return null;
    final title = exam.title.trim();
    final subject = exam.subject.trim();
    if (title.isEmpty) return subject.isEmpty ? null : subject;
    if (subject.isEmpty) return title;
    if (title.toLowerCase().contains(subject.toLowerCase())) return title;
    return '$title — $subject';
  }

  /// The insight sentence. Makes exactly the claims the data supports: no
  /// average before any mark is scored, and no exam/subject name when the
  /// active exam is unknown.
  static String _insightMessage(int? average, String? examLabel) {
    if (average == null) {
      return examLabel == null
          ? 'No marks have been entered yet, so there is no class average to '
              'show.'
          : 'No marks have been entered yet for $examLabel, so there is no '
              'class average to show.';
    }
    return examLabel == null
        ? 'Class average is $average% for the marks entered so far.'
        : 'Class average is $average% for $examLabel.';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final examId = ref.watch(teacherActiveExamIdProvider);
    final activeExam = ref.watch(teacherActiveExamProvider);
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
          message: _insightMessage(
            classAveragePercent,
            _examLabel(activeExam),
          ),
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

/// Contributes SLIVERS (not a box) so the roster below can be a lazily-built,
/// viewport-recycling [SliverList] inside the screen's single scroll view.
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

    return SliverMainAxisGroup(
      slivers: [
        if (activeExam != null)
          SliverToBoxAdapter(child: _ExamContextHeader(exam: activeExam)),
        if (options.length > 1) ...[
          const SliverToBoxAdapter(
            child: SizedBox(height: AksharaSpacing.s3),
          ),
          SliverToBoxAdapter(
            child: DropdownButtonFormField<String>(
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
          ),
          const SliverToBoxAdapter(
            child: SizedBox(height: AksharaSpacing.s3),
          ),
        ] else if (activeExam != null)
          const SliverToBoxAdapter(
            child: SizedBox(height: AksharaSpacing.s3),
          ),
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

/// The marks roster. Builds SLIVERS: the rows are a lazily-built
/// [SliverList.builder], so only the rows in (and just around) the viewport
/// mount a live `TextField` — a 40–60 student class no longer keeps 40–60 of
/// them alive at once. Controllers/focus nodes still live in this State, keyed
/// by entry id, so per-cell save dots, Enter-advances-to-next-student focus
/// traversal and dirty tracking survive a row being recycled off-screen (the
/// same design the exam-admin `ListView.separated` grid uses).
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
      return const SliverToBoxAdapter(
        child: AksharaEmptyState(
          message: 'No students for marks entry.',
          compact: true,
        ),
      );
    }

    final isClassTeacher =
        ref.watch(teacherIsClassTeacherForActiveExamProvider);
    final examId = ref.watch(teacherActiveExamIdProvider);

    final entries = widget.entries;
    final maxMarks = entries.first.maxMarks;

    // ONE pass over the roster for every footer/toolbar statistic (was four
    // full passes plus two intermediate list allocations, on every rebuild —
    // and this rebuilds on every keystroke).
    var entered = 0;
    var dirtyCount = 0;
    var percentSum = 0.0;
    for (final entry in entries) {
      if (entry.marksObtained != null) {
        entered++;
        percentSum += entry.maxMarks == 0
            ? 0.0
            : (entry.marksObtained! / entry.maxMarks) * 100;
      }
      if (_isDirty(entry)) dirtyCount++;
    }
    final avg = entered == 0 ? null : percentSum / entered;

    return SliverMainAxisGroup(
      slivers: [
        // P2-UX-2 §2.2 — Save-all changed rows in one action (dirty rows only).
        if (dirtyCount > 0)
          SliverToBoxAdapter(
            child: Padding(
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
          ),
        SliverList.builder(
          itemCount: entries.length,
          itemBuilder: (context, index) => _buildRow(
            context,
            entries[index],
            index,
            isClassTeacher,
            examId,
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: AksharaSpacing.s3),
            // Shared inline column-stats footer (same component the admin grid
            // uses).
            child: MarksColumnStats(
              key: QaTestKeys.marksColumnStats,
              entered: entered,
              total: entries.length,
              averagePercent: avg,
              maxMarks: maxMarks,
            ),
          ),
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
