import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/reliability/drafts/draft_autosave.dart';
import '../../../core/reliability/drafts/draft_model.dart';
import '../../../core/reports/akshara_report_export_service.dart';
import '../../../core/config/exam_approval_config.dart';
import '../../../core/exams/exam_administration_requests.dart';
import '../../../core/exams/exam_administration_store.dart';
import '../../../core/security/permissions.dart';
import '../../../core/security/rbac_service.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/feedback/akshara_haptics.dart';
import '../../../shared/marks_grid/marks_grid.dart';
import '../../../shared/widgets/akshara_view_action.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import 'exam_admin_models.dart';
import 'exam_administration_provider.dart';
import 'exam_marks_entry_provider.dart';
import 'exam_marks_progress_screen.dart';
import '../../../core/errors/error_text.dart';

/// ERP marks entry and publication chain for a single exam session.
class ExamMarksEntryScreen extends ConsumerWidget {
  const ExamMarksEntryScreen({super.key, required this.examId});

  final String examId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Load any backend-persisted remarks for this exam into the local cache so
    // class-teacher / leadership remarks survive restart and show cross-device.
    ref.watch(examRemarksHydrationProvider(examId));
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
          // EXM-2 — jump to the marks-entry progress board (who still owes marks).
          AksharaViewAction(
            permission: Permission.viewExams,
            child: IconButton(
              key: QaTestKeys.examMarksProgressButton,
              tooltip: 'Marks entry progress',
              icon: const Icon(Icons.checklist_rtl_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ExamMarksProgressScreen(),
                ),
              ),
            ),
          ),
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

class _MarksEntryBody extends ConsumerStatefulWidget {
  const _MarksEntryBody({
    required this.exam,
    required this.marks,
    required this.approvalRequired,
  });

  final ExamSession exam;
  final List<ExamMarkRecord> marks;
  final bool approvalRequired;

  @override
  ConsumerState<_MarksEntryBody> createState() => _MarksEntryBodyState();
}

class _MarksEntryBodyState extends ConsumerState<_MarksEntryBody>
    with DraftAutosaveMixin {
  ExamSession get exam => widget.exam;
  List<ExamMarkRecord> get marks => widget.marks;
  bool get approvalRequired => widget.approvalRequired;

  // EXM-1 — one controller + focus node per row so Enter/Tab jumps to the next
  // row's marks field and "Save all" can read every field. Keyed by mark id so
  // they survive list rebuilds (a save refresh re-emits the roster).
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};
  bool _savingAll = false;

  // REL-3 — draft values recovered from a prior interrupted session, keyed by
  // mark id. Applied when a row's controller is (re)created so an off-screen row
  // scrolled into view rehydrates its typed-but-unsaved mark, not the persisted
  // one. Cleared per-id once the row is saved through "Save all".
  final Map<String, String> _resumedDraftValues = {};

  /// REL-3 — one draft per exam marks grid; scoped to the signed-in teacher by
  /// [DraftController]. `exam_marks:{examId}`.
  String get _draftKey => 'exam_marks:${exam.id}';

  bool get _canEdit =>
      exam.phase == ExamLifecyclePhase.marksEntry ||
      exam.phase == ExamLifecyclePhase.scheduled;

  TextEditingController _controllerFor(ExamMarkRecord mark) {
    return _controllers.putIfAbsent(mark.id, () {
      final resumed = _resumedDraftValues[mark.id];
      final controller = TextEditingController(
        text: resumed ?? (mark.marksObtained?.toString() ?? ''),
      );
      // REL-3 — every keystroke schedules a debounced autosave of the dirty
      // grid (also flushed when the app is backgrounded), so a half-entered
      // roster survives a phone-lock / app-switch / kill.
      controller.addListener(scheduleDraftSave);
      return controller;
    });
  }

  FocusNode _focusFor(String markId) =>
      _focusNodes.putIfAbsent(markId, FocusNode.new);

  @override
  void initState() {
    super.initState();
    // REL-3 — offer to resume a prior interrupted marks entry (WhatsApp-draft
    // UX). Deferred to the first frame so the roster controllers exist.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      offerResumeIfAny(
        draftKey: _draftKey,
        onResume: (json) {
          final rawMarks = (json['marks'] as Map?) ?? const {};
          rawMarks.forEach((key, value) {
            final id = key as String;
            final text = value?.toString() ?? '';
            _resumedDraftValues[id] = text;
            _controllers[id]?.text = text;
          });
          if (mounted) setState(() {});
        },
      );
    });
  }

  /// REL-3 — snapshot of every dirty, editable row (typed value differs from the
  /// persisted mark). Returns null when nothing is worth saving so an untouched
  /// grid never leaves a stray draft.
  @override
  DraftModel? buildDraftSnapshot() {
    if (!_canEdit) return null;
    final dirty = <String, dynamic>{};
    for (final mark in marks) {
      if (mark.published || !mark.status.isPresent) continue;
      final controller = _controllers[mark.id];
      if (controller == null) continue;
      final raw = controller.text.trim();
      if (raw.isEmpty) continue;
      final parsed = int.tryParse(raw);
      if (parsed == null) continue;
      if (parsed == mark.marksObtained) continue; // unchanged vs persisted
      dirty[mark.id] = raw;
    }
    if (dirty.isEmpty) return null;
    return MapDraft(
      _draftKey,
      <String, dynamic>{'examId': exam.id, 'marks': dirty},
      draftLabel: 'Marks · ${exam.classLabel} · ${exam.subject}',
    );
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final f in _focusNodes.values) {
      f.dispose();
    }
    super.dispose();
  }

  /// EXM-1 — Enter/Tab on a row moves focus to the next editable (present,
  /// unpublished) row's marks field, so a teacher never leaves the keyboard.
  void _focusNextRow(int fromIndex) {
    for (var i = fromIndex + 1; i < marks.length; i++) {
      final next = marks[i];
      if (next.status.isPresent && !next.published && _canEdit) {
        _focusFor(next.id).requestFocus();
        return;
      }
    }
    // Last editable row: drop focus so the keyboard closes.
    FocusScope.of(context).unfocus();
  }

  /// EXM-1 — collect every dirty present row (field differs from persisted marks)
  /// and POST them as one batch, then show "N saved, M failed" and refresh.
  Future<void> _saveAll() async {
    final entries = <BulkExamMarkEntry>[];
    for (final mark in marks) {
      if (mark.published || !mark.status.isPresent) continue;
      final controller = _controllers[mark.id];
      if (controller == null) continue;
      final raw = controller.text.trim();
      final parsed = int.tryParse(raw);
      final persisted = mark.marksObtained;
      if (parsed == null) continue; // blank / non-numeric: nothing to save
      if (parsed == persisted) continue; // unchanged
      if (parsed < 0 || parsed > exam.maxMarks) continue; // guarded by backend too
      entries.add(
        BulkExamMarkEntry(
          markEntryId: mark.id,
          marksObtained: parsed,
          status: ExamMarkStatus.present,
        ),
      );
    }
    if (entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No changed marks to save.')),
      );
      return;
    }
    setState(() => _savingAll = true);
    try {
      final result = await ref
          .read(examMarksMutationProvider.notifier)
          .bulkSaveMarks(examId: exam.id, entries: entries);
      // REL-3 — the typed marks are now persisted (or safely queued): drop the
      // local draft + its resumed shadow so a completed grid is never re-offered.
      _resumedDraftValues.clear();
      unawaited(discardDraftOnSubmit(_draftKey));
      if (!mounted) return;
      // Success beat on a completed marks save-all (P2-UX-2 §2.2).
      AksharaHaptics.success();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${result.savedCount} saved, ${result.failedCount} failed',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(aksharaErrorMessage(error))),
      );
    } finally {
      if (mounted) setState(() => _savingAll = false);
    }
  }

  /// EXM-6 — human message for the marks-entry deadline banner. Flags a passed
  /// deadline; otherwise states the due date. Dates are rendered in local time.
  String _deadlineMessage(DateTime deadline) {
    final local = deadline.toLocal();
    final d = '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
    final t = '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
    final passed = DateTime.now().isAfter(deadline);
    return passed
        ? 'Marks-entry deadline passed ($d $t). Please complete entry.'
        : 'Marks-entry deadline: $d $t';
  }

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    final entered = marks
        .where((m) => !m.status.isPresent || m.marksObtained != null)
        .length;
    // Shared column-stats footer average: mean of the entered present marks.
    final scored =
        marks.where((m) => m.status.isPresent && m.marksObtained != null);
    final avgPercent = scored.isEmpty
        ? null
        : scored
                .map((m) => exam.maxMarks == 0
                    ? 0.0
                    : (m.marksObtained! / exam.maxMarks) * 100)
                .reduce((a, b) => a + b) /
            scored.length;
    final canEdit = _canEdit;

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
              const SizedBox(height: AksharaSpacing.s2),
              // Shared spreadsheet-grade column-stats footer (P2-UX-2 §2.2/2.5 —
              // the SAME component the teacher marks grid renders).
              MarksColumnStats(
                key: QaTestKeys.marksColumnStats,
                entered: entered,
                total: marks.length,
                averagePercent: avgPercent,
                maxMarks: exam.maxMarks,
              ),
              // EXM-6 — surface the marks-entry deadline (if set) as a banner.
              // The automated teacher reminder rides a future reminder-rule
              // engine (XCT-2); this is only the informational surface.
              if (exam.marksEntryDeadline != null) ...[
                const SizedBox(height: AksharaSpacing.s2),
                AksharaWarningBanner(
                  message: _deadlineMessage(exam.marksEntryDeadline!),
                ),
              ],
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
            itemBuilder: (context, index) => _MarkEntryRow(
              mark: marks[index],
              exam: exam,
              canEdit: canEdit,
              controller: _controllerFor(marks[index]),
              focusNode: _focusFor(marks[index].id),
              onSubmitted: () => _focusNextRow(index),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          child: Wrap(
            spacing: AksharaSpacing.s2,
            runSpacing: AksharaSpacing.s2,
            children: [
              // EXM-1 — Save all changed rows in one batch.
              if (canEdit && exam.phase == ExamLifecyclePhase.marksEntry)
                AksharaViewAction(
                  permission: Permission.manageExamMarks,
                  child: FilledButton.icon(
                    key: QaTestKeys.examAdminMarksSaveAllButton,
                    onPressed: _savingAll ? null : _saveAll,
                    icon: _savingAll
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.done_all),
                    label: const Text('Save all'),
                  ),
                ),
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
        SnackBar(content: Text(aksharaErrorMessage(error))),
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
        SnackBar(content: Text(aksharaErrorMessage(error))),
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
        SnackBar(content: Text(aksharaErrorMessage(error))),
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
        SnackBar(content: Text(aksharaErrorMessage(error))),
      );
    }
  }
}

class _MarkEntryRow extends ConsumerStatefulWidget {
  const _MarkEntryRow({
    required this.mark,
    required this.exam,
    required this.canEdit,
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
  });

  final ExamMarkRecord mark;
  final ExamSession exam;
  final bool canEdit;

  // EXM-1 — owned by the parent grid so Enter/Tab focus chaining + "Save all"
  // can read every row's field.
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmitted;

  @override
  ConsumerState<_MarkEntryRow> createState() => _MarkEntryRowState();
}

class _MarkEntryRowState extends ConsumerState<_MarkEntryRow> {
  TextEditingController get _controller => widget.controller;
  bool _saving = false;

  @override
  void didUpdateWidget(covariant _MarkEntryRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final current = widget.mark.marksObtained?.toString() ?? '';
    final previous = oldWidget.mark.marksObtained?.toString() ?? '';
    // Pull the persisted value into the field only when the SERVER value
    // actually changed (a save / roster refresh emitted a new mark) — not on
    // every parent rebuild — so unsaved typing and a restored draft (REL-3) are
    // never clobbered. Never override an actively edited (focused) or in-flight
    // (saving) field.
    if (current != previous &&
        _controller.text != current &&
        !_saving &&
        !widget.focusNode.hasFocus) {
      _controller.text = current;
    }
  }

  Future<void> _save() async {
    // A non-present student has no marks to validate — persist the status only.
    if (!widget.mark.status.isPresent) {
      await _persist(marks: 0, status: widget.mark.status);
      return;
    }
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
    await _persist(marks: parsed, status: ExamMarkStatus.present);
  }

  /// EXM-D6 — the teacher picked a new attendance status for this student.
  ///  * A non-present status (AB/ML/DB) clears the marks field and saves
  ///    immediately (no marks needed).
  ///  * Switching back to Present only UNLOCKS the field — nothing is persisted
  ///    until the teacher enters marks and saves (the backend requires marks for
  ///    a present student), so we never write a spurious 0.
  Future<void> _onStatusChanged(ExamMarkStatus status) async {
    if (status == widget.mark.status) return;
    if (!status.isPresent) {
      _controller.text = '';
      await _persist(marks: 0, status: status);
    } else {
      final parsed = int.tryParse(_controller.text.trim());
      if (parsed != null && parsed >= 0 && parsed <= widget.exam.maxMarks) {
        await _persist(marks: parsed, status: ExamMarkStatus.present);
      } else {
        // No valid marks yet — prompt the teacher to enter marks then save.
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter marks, then Save.')),
        );
      }
    }
  }

  Future<void> _persist({
    required int marks,
    required ExamMarkStatus status,
  }) async {
    setState(() => _saving = true);
    try {
      await ref.read(examMarksMutationProvider.notifier).updateMark(
            markEntryId: widget.mark.id,
            marksObtained: marks,
            status: status,
            // REL-5 — send the base row_version so a concurrent overwrite of
            // this student's mark is caught on the first save (lost-update guard).
            expectedVersion: widget.mark.rowVersion,
          );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(aksharaErrorMessage(error))),
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
        SnackBar(content: Text(aksharaErrorMessage(error))),
      );
    }
  }

  /// EXM-D2 — coordinator grace / moderation for THIS student. A signed delta +
  /// a mandatory reason. The ORIGINAL mark is preserved (a separate audited
  /// record); the effective total updates on refresh. Never shown to parents.
  Future<void> _openGraceDialog() async {
    final deltaController = TextEditingController();
    final reasonController = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Grace / moderation · ${widget.mark.studentName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Adjust the mark by a signed amount. The original mark is kept; '
              'only the coordinator sees this adjustment.',
              style: context.aksharaText.bodySmall,
            ),
            const SizedBox(height: AksharaSpacing.s3),
            TextField(
              key: QaTestKeys.examAdminGraceDeltaField,
              controller: deltaController,
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^-?\d*')),
              ],
              decoration: const InputDecoration(
                labelText: 'Delta (e.g. 5 or -2)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AksharaSpacing.s2),
            TextField(
              key: QaTestKeys.examAdminGraceReasonField,
              controller: reasonController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Reason (required)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: QaTestKeys.examAdminGraceSubmitButton,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    if (saved != true) return;
    final delta = int.tryParse(deltaController.text.trim());
    if (delta == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a whole-number delta.')),
      );
      return;
    }
    try {
      final result =
          await ref.read(examMarksMutationProvider.notifier).recordGraceMark(
                examId: widget.exam.id,
                sisStudentId: widget.mark.sisStudentId,
                delta: delta,
                reason: reasonController.text,
              );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Grace applied · effective ${result.effectiveMark}/${result.maxMarks}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(aksharaErrorMessage(error))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    final canRemark = ref.watch(canAuthorLeadershipExamRemarkProvider);
    // EXM-D2 — grace is a coordinator action, only before publish, and only for a
    // present student who has an entered mark to moderate.
    final canModerate =
        ref.watch(rbacServiceProvider).hasPermission(Permission.moderateExamMarks);
    final showGrace = canModerate &&
        widget.exam.phase == ExamLifecyclePhase.processed &&
        widget.mark.status.isPresent &&
        widget.mark.marksObtained != null;

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
            if (showGrace)
              IconButton(
                key: QaTestKeys.examAdminGraceButton(widget.mark.id),
                tooltip: 'Grace / moderation',
                icon: const Icon(Icons.tune_outlined),
                onPressed: _openGraceDialog,
              ),
            if (canRemark)
              IconButton(
                key: QaTestKeys.examLeadershipRemarkButton(widget.mark.id),
                tooltip: 'Leadership remark',
                icon: const Icon(Icons.rate_review_outlined),
                onPressed: _openLeadershipRemarkDialog,
              ),
            // EXM-D6 — attendance status selector. A non-present status locks the
            // marks field and shows the display code (AB/ML/DB).
            PopupMenuButton<ExamMarkStatus>(
              key: QaTestKeys.examAdminMarkStatusSelector(widget.mark.id),
              tooltip: 'Attendance status',
              enabled: widget.canEdit && !widget.mark.published,
              initialValue: widget.mark.status,
              onSelected: _onStatusChanged,
              itemBuilder: (context) => [
                for (final status in ExamMarkStatus.values)
                  PopupMenuItem<ExamMarkStatus>(
                    value: status,
                    child: Text(status.label),
                  ),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AksharaSpacing.s2,
                ),
                child: Text(
                  widget.mark.status.displayCode ?? 'P',
                  style: text.labelLarge,
                ),
              ),
            ),
            const SizedBox(width: AksharaSpacing.s2),
            SizedBox(
              width: 88,
              child: widget.mark.status.isPresent
                  ? TextField(
                      key: QaTestKeys.examAdminMarkField(widget.mark.id),
                      controller: _controller,
                      focusNode: widget.focusNode,
                      enabled: widget.canEdit && !widget.mark.published,
                      keyboardType: TextInputType.number,
                      // EXM-1 — Enter/Tab advances to the next editable row.
                      textInputAction: TextInputAction.next,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: InputDecoration(
                        labelText: 'Marks',
                        isDense: true,
                        suffixText: '/${widget.exam.maxMarks}',
                      ),
                      // Persist this row, then jump focus to the next one so a
                      // teacher can key straight down the roster.
                      onSubmitted: (_) async {
                        await _save();
                        widget.onSubmitted();
                      },
                    )
                  // Non-present: field is locked; show the display code instead.
                  : InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Marks',
                        isDense: true,
                        enabled: false,
                      ),
                      child: Text(
                        widget.mark.status.displayCode ?? '',
                        style: text.bodyLarge,
                      ),
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
