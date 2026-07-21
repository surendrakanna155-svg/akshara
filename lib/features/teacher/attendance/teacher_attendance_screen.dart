import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/reliability/drafts/draft_autosave.dart';
import '../../../core/reliability/drafts/draft_model.dart';
import '../../../core/reports/akshara_report_export_service.dart';
import '../../../core/security/permissions.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/widgets/akshara_view_action.dart';
import '../../../shared/feedback/akshara_haptics.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../communication/teacher_teaching_context_provider.dart';
import '../reports/teacher_report_exporters.dart';
import '../reports/teacher_report_share_sheet.dart';
import 'attendance_models.dart';
import 'teacher_attendance_provider.dart';
import 'teacher_attendance_workflow.dart';
import 'widgets/class_selector_strip.dart';
import 'widgets/attendance_exception_grid.dart';
import '../../../theme/breakpoints.dart';

/// Teacher attendance marking — TA-02.
class TeacherAttendanceScreen extends ConsumerStatefulWidget {
  const TeacherAttendanceScreen({
    super.key,
    this.onNotificationsTap,
    this.preselectClassLabel,
  });

  final VoidCallback? onNotificationsTap;

  /// TCH-1 — a class label (e.g. `8-A`) to pre-select on entry, from a tapped
  /// today-period. The first roster class whose label matches wins.
  final String? preselectClassLabel;

  static const double _tabletBreakpoint = AksharaBreakpoints.tabletMinWidth;
  static const double _tabletMaxContentWidth = AksharaBreakpoints.compactContentMaxWidth;

  @override
  ConsumerState<TeacherAttendanceScreen> createState() =>
      _TeacherAttendanceScreenState();
}

class _TeacherAttendanceScreenState
    extends ConsumerState<TeacherAttendanceScreen> {
  int _preselectAttempts = 0;

  @override
  void initState() {
    super.initState();
    final label = widget.preselectClassLabel;
    if (label == null) return;
    // Pre-select once the roster classes have resolved.
    WidgetsBinding.instance.addPostFrameCallback((_) => _preselect(label));
  }

  void _preselect(String label) {
    if (!mounted) return;
    final classes = ref.read(teacherAttendanceProvider).classes;
    for (final c in classes) {
      if (c.label == label) {
        ref.read(teacherAttendanceClassProvider.notifier).state = c.id;
        return;
      }
    }
    // Roster may still be loading — retry a bounded number of frames until it
    // resolves, then give up (label not in this teacher's roster).
    if (classes.isEmpty && _preselectAttempts < 10) {
      _preselectAttempts++;
      WidgetsBinding.instance.addPostFrameCallback((_) => _preselect(label));
    }
  }

  @override
  Widget build(BuildContext context) {
    final onNotificationsTap = widget.onNotificationsTap;
    final data = ref.watch(teacherAttendanceProvider);
    final isLoading = ref.watch(teacherAttendanceLoadingProvider);
    final hasError = ref.watch(teacherAttendanceErrorProvider);
    final teaching = ref.watch(resolvedTeacherTeachingContextProvider);

    return Scaffold(
      backgroundColor: context.colors.surfaceContainerLow,
      appBar: AksharaAppBar(
        titleText: 'Mark Attendance',
        subtitle: teaching.appBarSubtitle,
        unreadNotifications: data.unreadNotifications,
        trailingPadding: true,
        onNotificationsTap: onNotificationsTap,
        additionalActions: [
          // TCH-3 — export the class register + summary (XCT-1 grid CSV/PDF).
          IconButton(
            key: QaTestKeys.teacherAttendanceExportButton,
            tooltip: 'Export register',
            onPressed: data.students.isEmpty
                ? null
                : () {
                    final exporters = TeacherReportExporters(
                      ref.read(aksharaReportExportServiceProvider),
                    );
                    showTeacherExportSheet(
                      context,
                      title: 'Export attendance register',
                      onCsv: () => exporters.shareAttendanceRegisterCsv(data),
                      onPdf: () => exporters.shareAttendanceRegisterPdf(data),
                    );
                  },
            icon: const Icon(Icons.ios_share_outlined),
          ),
        ],
      ),
      body: isLoading
          ? const AksharaLoadingState(semanticLabel: 'Loading attendance')
          : hasError
              ? AksharaErrorState(
                  message: 'Unable to load attendance roster.',
                  onRetry: () => ref
                      .read(teacherAttendanceErrorProvider.notifier)
                      .state = false,
                )
              : data.classes.isEmpty
                  ? const AksharaEmptyState(
                      message: 'No classes scheduled for attendance.',
                      icon: Icons.class_outlined,
                    )
                  : _AttendanceBody(data: data),
    );
  }
}

class _AttendanceBody extends ConsumerStatefulWidget {
  const _AttendanceBody({required this.data});

  final TeacherAttendanceData data;

  @override
  ConsumerState<_AttendanceBody> createState() => _AttendanceBodyState();
}

class _AttendanceBodyState extends ConsumerState<_AttendanceBody>
    with DraftAutosaveMixin {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  String _draftKeyFor(String classId) => 'attendance:$classId';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final classId = widget.data.selectedClassId;
      offerResumeIfAny(
        draftKey: _draftKeyFor(classId),
        onResume: (json) {
          final rawMarks = (json['marks'] as Map?) ?? const {};
          final marks = <String, StudentAttendanceMark>{
            for (final entry in rawMarks.entries)
              entry.key as String: StudentAttendanceMark.values.firstWhere(
                (m) => m.name == entry.value,
                orElse: () => StudentAttendanceMark.unmarked,
              ),
          };
          restoreAttendanceMarks(ref, classId: classId, marks: marks);
        },
      );
    });
  }

  @override
  DraftModel? buildDraftSnapshot() {
    final data = widget.data;
    if (data.isSubmitted) return null;
    final hasAnyMark =
        data.students.any((s) => s.mark != StudentAttendanceMark.unmarked);
    if (!hasAnyMark) return null;
    return MapDraft(
      _draftKeyFor(data.selectedClassId),
      <String, dynamic>{
        'classId': data.selectedClassId,
        'marks': <String, dynamic>{
          for (final s in data.students)
            if (s.mark != StudentAttendanceMark.unmarked) s.id: s.mark.name,
        },
      },
      draftLabel: 'Attendance roster',
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// F-080 — a bulk "All present"/"All absent" is a destructive overwrite of an
  /// in-progress roster: it wipes explicit marks AND lets the debounced autosave
  /// persist the wiped state over the recoverable draft. Guard it two ways:
  ///  1. Confirm first ONLY when the action would overwrite students who are
  ///     already marked (a blank roster applies directly — no needless friction;
  ///     the non-destructive "Fill remaining present" fast path is untouched).
  ///  2. After applying, offer a SnackBar Undo that restores the exact prior
  ///     roster. Restoring re-writes the provider state, which re-arms the
  ///     debounced autosave (via the `ref.listen` in [build]) so the RESTORED
  ///     roster — not the wiped one — is what gets persisted.
  Future<void> _handleBulkMark(StudentAttendanceMark mark) async {
    final data = ref.read(teacherAttendanceProvider);
    if (data.isSubmitted) return;
    final students = data.students;
    if (students.isEmpty) return;

    // Snapshot the exact prior roster (incl. unmarked rows) so Undo restores it.
    final priorMarks = <String, StudentAttendanceMark>{
      for (final s in students) s.id: s.mark,
    };
    final alreadyMarked = students
        .where((s) => s.mark != StudentAttendanceMark.unmarked)
        .length;

    if (alreadyMarked > 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Overwrite existing marks?'),
          content: Text(
            'Marking all ${mark.label.toLowerCase()} will overwrite '
            '$alreadyMarked ${alreadyMarked == 1 ? 'student' : 'students'} '
            'you have already marked.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Overwrite'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    applyBulkMark(ref, mark);

    if (!mounted) return;
    final classId = data.selectedClassId;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text('Marked all ${mark.label.toLowerCase()}.'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            if (!mounted) return;
            restoreAttendanceMarks(ref, classId: classId, marks: priorMarks);
          },
        ),
      ),
    );
  }

  List<TeacherAttendanceStudent> get _visibleStudents {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.data.students;
    return widget.data.students
        .where((s) =>
            s.name.toLowerCase().contains(q) ||
            s.rollNo.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    // Autosave the in-progress roster as marks change (debounced + flushed when
    // the app is backgrounded), so a half-marked roster is never lost.
    ref.listen(teacherAttendanceProvider, (_, __) => scheduleDraftSave());

    final data = widget.data;
    final visibleStudents = _visibleStudents;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth >=
            TeacherAttendanceScreen._tabletBreakpoint;
        final horizontalPadding = isTablet
            ? AksharaSpacing.tabletMargin
            : AksharaSpacing.mobileMargin;

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isTablet
                  ? TeacherAttendanceScreen._tabletMaxContentWidth
                  : double.infinity,
            ),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    AksharaSpacing.s4,
                    horizontalPadding,
                    AksharaSpacing.s3,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ClassSelectorStrip(
                        classes: data.classes,
                        selectedClassId: data.selectedClassId,
                        onClassSelected: (id) => ref
                            .read(teacherAttendanceClassProvider.notifier)
                            .state = id,
                      ),
                      const SizedBox(height: AksharaSpacing.s3),
                      if (data.draftSavedAt != null) ...[
                        const SizedBox(height: AksharaSpacing.s2),
                        AksharaWarningBanner(
                          message: 'Draft saved at ${data.draftSavedAt}',
                        ),
                      ],
                      if (data.isSubmitted) ...[
                        const SizedBox(height: AksharaSpacing.s2),
                        const AksharaWarningBanner(
                          key: QaTestKeys.teacherAttendanceSubmittedBanner,
                          message: 'Attendance submitted successfully.',
                        ),
                        const SizedBox(height: AksharaSpacing.s2),
                        AksharaViewAction(
                          permission: Permission.submitAttendanceCorrection,
                          child: OutlinedButton.icon(
                            key: QaTestKeys.teacherAttendanceCorrectionButton,
                            onPressed: () => showAttendanceCorrectionDialog(
                              context,
                              ref,
                              data: data,
                            ),
                            icon: const Icon(Icons.edit_calendar_outlined),
                            label: const Text('Request correction'),
                          ),
                        ),
                      ],
                      const SizedBox(height: AksharaSpacing.s3),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _handleBulkMark(
                                StudentAttendanceMark.present,
                              ),
                              child: const Text('All present'),
                            ),
                          ),
                          const SizedBox(width: AksharaSpacing.s2),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _handleBulkMark(
                                StudentAttendanceMark.absent,
                              ),
                              child: const Text('All absent'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AksharaSpacing.s2),
                      // ATT-3: absentees-first — mark only the still-unmarked
                      // students present after tapping the few absentees.
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          key: QaTestKeys.teacherAttendanceFillRemainingButton,
                          onPressed: () => fillRemainingAsPresent(ref),
                          icon: const Icon(Icons.done_all_outlined, size: 18),
                          label: const Text('Fill remaining present'),
                        ),
                      ),
                      const SizedBox(height: AksharaSpacing.s3),
                      TextField(
                        key: QaTestKeys.teacherAttendanceSearchField,
                        controller: _searchController,
                        onChanged: (value) => setState(() => _query = value),
                        decoration: InputDecoration(
                          hintText: 'Search by name or roll number',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _query.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.clear),
                                  tooltip: 'Clear search',
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _query = '');
                                  },
                                ),
                          isDense: true,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: visibleStudents.isEmpty
                      ? const Center(
                          child: SingleChildScrollView(
                            child: AksharaEmptyState(
                              message: 'No students match your search.',
                              icon: Icons.search_off_outlined,
                              compact: true,
                            ),
                          ),
                        )
                      // P2-UX-2 §2.1 — exception-first: a dense grid so the class
                      // fits with minimal scrolling; mark all present, tap only
                      // the exceptions. Same marking workflow as the row.
                      : AttendanceExceptionGrid(
                          students: visibleStudents,
                          enabled: !data.isSubmitted,
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPadding,
                          ),
                          onMark: (studentId, mark) => updateStudentMark(
                            ref,
                            studentId: studentId,
                            mark: mark,
                          ),
                        ),
                ),
                _AttendanceActionBar(
                  horizontalPadding: horizontalPadding,
                  canSubmit: data.unmarkedCount == 0 && !data.isSubmitted,
                  unmarkedCount: data.unmarkedCount,
                  presentCount: data.presentCount,
                  absentCount: data.absentCount,
                  lateCount: data.lateCount,
                  onSaveDraft: () => saveAttendanceDraft(ref),
                  onSubmit: () async {
                    final classId = data.selectedClassId;
                    final ok = await submitAttendance(ref);
                    if (ok) {
                      // Success beat on a completed submit (P2-UX-2 §2.1).
                      AksharaHaptics.success();
                      // Submitted (or safely queued) — drop the local draft.
                      await discardDraftOnSubmit(_draftKeyFor(classId));
                    }
                    if (!context.mounted) return;
                    if (!ok) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Mark all students before submitting.'),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AttendanceActionBar extends StatelessWidget {
  const _AttendanceActionBar({
    required this.horizontalPadding,
    required this.canSubmit,
    required this.unmarkedCount,
    required this.presentCount,
    required this.absentCount,
    required this.lateCount,
    required this.onSaveDraft,
    required this.onSubmit,
  });

  final double horizontalPadding;
  final bool canSubmit;
  final int unmarkedCount;
  final int presentCount;
  final int absentCount;
  final int lateCount;
  final VoidCallback onSaveDraft;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Material(
      color: colors.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            AksharaSpacing.s3,
            horizontalPadding,
            AksharaSpacing.s3,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // P2-UX-2 §2.1 — the single sticky live tally, right above Submit:
              // "N present · M absent · K late" (never says "unmarked" — that
              // stays the submit CTA's job so the gate reads in one place).
              Padding(
                key: QaTestKeys.teacherAttendanceSummaryBar,
                padding: const EdgeInsets.only(bottom: AksharaSpacing.s2),
                child: Row(
                  children: [
                    Icon(
                      Icons.fact_check_outlined,
                      size: 18,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: AksharaSpacing.s2),
                    Expanded(
                      child: Text(
                        '$presentCount present · $absentCount absent · '
                        '$lateCount late',
                        style: text.bodyMedium.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onSaveDraft,
                      child: const Text('Save draft'),
                    ),
                  ),
                  const SizedBox(width: AksharaSpacing.s3),
                  Expanded(
                    child: FilledButton(
                      key: QaTestKeys.teacherAttendanceSubmitButton,
                      onPressed: canSubmit ? onSubmit : null,
                      child: Text(
                        unmarkedCount > 0
                            ? '$unmarkedCount unmarked'
                            : 'Submit',
                      ),
                    ),
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
