import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/testing/qa_test_keys.dart';
import '../../../router/route_names.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../communication/teacher_teaching_context_provider.dart';
import '../teacher_mutations_provider.dart';
import '../teacher_requests.dart';
import '../teacher_unread_provider.dart';
import 'homework_models.dart';
import 'teacher_homework_provider.dart';
import 'widgets/homework_submission_row.dart';
import '../../../theme/breakpoints.dart';

/// Teacher homework review — TA-04.
class TeacherHomeworkScreen extends ConsumerStatefulWidget {
  const TeacherHomeworkScreen({
    super.key,
    this.onNotificationsTap,
    this.initialPendingOnly = false,
  });

  final VoidCallback? onNotificationsTap;

  /// TCH-6 — when true (the `?filter=pending` deep-link from the "HW to review"
  /// task), the review list opens filtered to still-unreviewed submissions.
  final bool initialPendingOnly;

  static const double _tabletBreakpoint = AksharaBreakpoints.tabletMinWidth;
  static const double _tabletMaxContentWidth = AksharaBreakpoints.compactContentMaxWidth;

  @override
  ConsumerState<TeacherHomeworkScreen> createState() =>
      _TeacherHomeworkScreenState();
}

class _TeacherHomeworkScreenState extends ConsumerState<TeacherHomeworkScreen> {
  @override
  void initState() {
    super.initState();
    // Apply the deep-link filter once, after the first frame, so it survives the
    // navigation into this screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(teacherHomeworkReviewFilterProvider.notifier).state =
          widget.initialPendingOnly
              ? HomeworkReviewFilter.pendingOnly
              : HomeworkReviewFilter.all;
    });
  }

  @override
  Widget build(BuildContext context) {
    final onNotificationsTap = widget.onNotificationsTap;
    final assignments = ref.watch(teacherHomeworkAssignmentsProvider);
    final selected = ref.watch(teacherHomeworkProvider);
    final isLoading = ref.watch(teacherHomeworkLoadingProvider);
    final hasError = ref.watch(teacherHomeworkErrorProvider);
    final teaching = ref.watch(resolvedTeacherTeachingContextProvider);

    return Scaffold(
      backgroundColor: context.colors.surfaceContainerLow,
      appBar: AksharaAppBar(
        titleText: 'Homework Review',
        subtitle: teaching.appBarSubtitle,
        unreadNotifications: ref.watch(teacherUnreadNotificationsProvider),
        trailingPadding: true,
        onNotificationsTap: onNotificationsTap,
        additionalActions: [
          IconButton(
            tooltip: 'Homework history',
            onPressed: () => context.push(RouteNames.teacherHomeworkHistory),
            icon: const Icon(Icons.history_outlined),
          ),
        ],
      ),
      body: isLoading
          ? const AksharaLoadingState()
          : hasError
              ? AksharaErrorState(
                  message: 'Unable to load homework submissions.',
                  onRetry: () => ref
                      .read(teacherHomeworkErrorProvider.notifier)
                      .state = false,
                )
              : assignments.isEmpty || selected == null
                  ? const AksharaEmptyState(
                      message: 'No homework assignments to review.',
                      icon: Icons.assignment_outlined,
                    )
                  : _HomeworkBody(assignment: selected, assignments: assignments),
    );
  }
}

class _HomeworkBody extends ConsumerStatefulWidget {
  const _HomeworkBody({
    required this.assignment,
    required this.assignments,
  });

  final TeacherHomeworkAssignment assignment;
  final List<TeacherHomeworkAssignment> assignments;

  @override
  ConsumerState<_HomeworkBody> createState() => _HomeworkBodyState();
}

class _HomeworkBodyState extends ConsumerState<_HomeworkBody> {
  // HWK-6 — the set of submission ids the teacher has selected for bulk review.
  final Set<String> _selected = <String>{};

  void _resetSelection() => setState(_selected.clear);

  @override
  void didUpdateWidget(covariant _HomeworkBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Clear the selection when the teacher switches to a different assignment.
    if (oldWidget.assignment.id != widget.assignment.id) {
      _selected.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final assignment = widget.assignment;
    final assignments = widget.assignments;

    return DefaultTabController(
      length: 2,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isTablet =
              constraints.maxWidth >= TeacherHomeworkScreen._tabletBreakpoint;
          final pad = isTablet
              ? AksharaSpacing.tabletMargin
              : AksharaSpacing.mobileMargin;

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isTablet
                    ? TeacherHomeworkScreen._tabletMaxContentWidth
                    : double.infinity,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      pad,
                      AksharaSpacing.s4,
                      pad,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _kpiRow(assignment),
                        const SizedBox(height: AksharaSpacing.s4),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: assignment.id,
                          decoration: const InputDecoration(
                            labelText: 'Assignment',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            for (final item in assignments)
                              DropdownMenuItem(
                                value: item.id,
                                child: Text(
                                  '${item.classLabel} · ${item.title}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              ref
                                  .read(teacherHomeworkAssignmentProvider
                                      .notifier)
                                  .state = value;
                              _resetSelection();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AksharaSpacing.s2),
                  TabBar(
                    tabs: [
                      Tab(
                        key: QaTestKeys.teacherHomeworkTabSubmissions,
                        text: 'Submissions (${assignment.submissions.length})',
                      ),
                      Tab(
                        key: QaTestKeys.teacherHomeworkTabNotSubmitted,
                        child: Consumer(
                          builder: (context, ref, _) {
                            final async = ref
                                .watch(teacherHomeworkNonSubmittersProvider);
                            final count = async.valueOrNull?.length;
                            return Text(
                              count == null
                                  ? 'Not submitted'
                                  : 'Not submitted ($count)',
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _SubmissionsTab(
                          assignment: assignment,
                          selected: _selected,
                          onToggle: (id, value) {
                            setState(() {
                              if (value) {
                                _selected.add(id);
                              } else {
                                _selected.remove(id);
                              }
                            });
                          },
                          onReview: (submission) => _showReviewSheet(
                            context,
                            assignment.id,
                            submission,
                          ),
                          onBulkReview: () =>
                              _bulkReview(context, assignment),
                          onNotify: () => _notify(context, assignment),
                          pad: pad,
                        ),
                        _NotSubmittedTab(pad: pad),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _kpiRow(TeacherHomeworkAssignment assignment) {
    return SizedBox(
      height: 88,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: AksharaKpiCard(
              value: '${assignment.pendingCount}',
              subtitle: 'Pending review',
              accent: KpiAccent.warning,
              icon: Icons.rate_review_outlined,
            ),
          ),
          const SizedBox(width: AksharaSpacing.s2),
          Expanded(
            child: AksharaKpiCard(
              value: '${assignment.submissions.length}',
              subtitle: 'Submissions',
              accent: KpiAccent.primary,
              icon: Icons.assignment_turned_in_outlined,
            ),
          ),
        ],
      ),
    );
  }

  // HWK-6 — bulk mark reviewed: the selected ids, or (none selected) all pending.
  Future<void> _bulkReview(
    BuildContext context,
    TeacherHomeworkAssignment assignment,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final result =
        await ref.read(bulkReviewTeacherHomeworkProvider.notifier).execute(
              TeacherHomeworkBulkReviewRequest(
                homeworkId: assignment.id,
                submissionIds: _selected.toList(),
                grade: 'A',
              ),
            );
    if (!mounted) return;
    _resetSelection();
    ref.invalidate(teacherHomeworkFutureProvider);
    ref.invalidate(teacherHomeworkNonSubmittersProvider);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          result == null
              ? 'Could not mark reviewed.'
              : 'Reviewed ${result.reviewed}'
                  '${result.skipped > 0 ? ' · skipped ${result.skipped}' : ''}.',
        ),
      ),
    );
  }

  // HWK-D1 — manual parent no-submit nudge.
  Future<void> _notify(
    BuildContext context,
    TeacherHomeworkAssignment assignment,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await ref
        .read(notifyHomeworkNonSubmittersProvider.notifier)
        .execute(assignment.id);
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          result == null
              ? 'Could not send reminders.'
              : 'Reminder queued for ${result.studentsPending} student(s).',
        ),
      ),
    );
  }

  void _showReviewSheet(
    BuildContext context,
    String assignmentId,
    HomeworkSubmission submission,
  ) {
    final gradeController = TextEditingController(text: 'A');
    final commentController = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          AksharaSpacing.s4,
          AksharaSpacing.s2,
          AksharaSpacing.s4,
          MediaQuery.paddingOf(context).bottom + AksharaSpacing.s4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Review ${submission.studentName}',
                style: context.aksharaText.titleMedium),
            const SizedBox(height: AksharaSpacing.s3),
            TextField(
              controller: gradeController,
              decoration: const InputDecoration(
                labelText: 'Grade',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AksharaSpacing.s3),
            TextField(
              controller: commentController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Comment',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AksharaSpacing.s4),
            FilledButton(
              onPressed: () {
                reviewSubmission(
                  ref,
                  assignmentId: assignmentId,
                  submissionId: submission.id,
                  grade: gradeController.text.trim(),
                  comment: commentController.text.trim(),
                );
                Navigator.pop(context);
              },
              child: const Text('Save review'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubmissionsTab extends ConsumerWidget {
  const _SubmissionsTab({
    required this.assignment,
    required this.selected,
    required this.onToggle,
    required this.onReview,
    required this.onBulkReview,
    required this.onNotify,
    required this.pad,
  });

  final TeacherHomeworkAssignment assignment;
  final Set<String> selected;
  final void Function(String id, bool value) onToggle;
  final void Function(HomeworkSubmission submission) onReview;
  final VoidCallback onBulkReview;
  final VoidCallback onNotify;
  final double pad;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingSubmissions = assignment.submissions
        .where((s) => s.status == HomeworkReviewStatus.pending)
        .toList();

    // TCH-6 — when the pending-only deep-link filter is active, the list shows
    // just the unreviewed submissions.
    final pendingOnly = ref.watch(teacherHomeworkReviewFilterProvider) ==
        HomeworkReviewFilter.pendingOnly;
    final visibleSubmissions =
        pendingOnly ? pendingSubmissions : assignment.submissions;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        pad,
        AksharaSpacing.s3,
        pad,
        AksharaSpacing.s6,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AksharaSectionHeader(
            title: assignment.title,
            trailingLabel: assignment.dueLabel,
            fixedHeight: false,
          ),
          if (pendingOnly) ...[
            const SizedBox(height: AksharaSpacing.s2),
            Align(
              alignment: Alignment.centerLeft,
              child: InputChip(
                avatar: const Icon(Icons.filter_alt_outlined, size: 18),
                label: const Text('Pending review only'),
                onDeleted: () => ref
                    .read(teacherHomeworkReviewFilterProvider.notifier)
                    .state = HomeworkReviewFilter.all,
              ),
            ),
          ],
          const SizedBox(height: AksharaSpacing.s2),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: QaTestKeys.teacherHomeworkBulkReviewButton,
                  onPressed: pendingSubmissions.isEmpty ? null : onBulkReview,
                  icon: const Icon(Icons.done_all, size: 18),
                  label: Text(
                    selected.isEmpty
                        ? 'Mark all reviewed'
                        : 'Review selected (${selected.length})',
                  ),
                ),
              ),
              const SizedBox(width: AksharaSpacing.s2),
              Expanded(
                child: OutlinedButton.icon(
                  key: QaTestKeys.teacherHomeworkNotifyButton,
                  onPressed: onNotify,
                  icon: const Icon(Icons.notifications_active_outlined, size: 18),
                  label: const Text('Nudge parents'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AksharaSpacing.s3),
          if (visibleSubmissions.isEmpty)
            AksharaEmptyState(
              message: pendingOnly
                  ? 'No submissions pending review.'
                  : 'No submissions yet.',
              icon: pendingOnly
                  ? Icons.task_alt_outlined
                  : Icons.assignment_outlined,
              compact: true,
            )
          else
            Column(
              children: [
                for (var i = 0; i < visibleSubmissions.length; i++) ...[
                  Row(
                    children: [
                      if (visibleSubmissions[i].status ==
                          HomeworkReviewStatus.pending)
                        Checkbox(
                          key: QaTestKeys.teacherHomeworkSubmissionCheckbox(
                            visibleSubmissions[i].id,
                          ),
                          value:
                              selected.contains(visibleSubmissions[i].id),
                          onChanged: (value) => onToggle(
                            visibleSubmissions[i].id,
                            value ?? false,
                          ),
                        )
                      else
                        const SizedBox(width: 48),
                      Expanded(
                        child: HomeworkSubmissionRow(
                          submission: visibleSubmissions[i],
                          onReview: visibleSubmissions[i].status ==
                                  HomeworkReviewStatus.pending
                              ? () => onReview(visibleSubmissions[i])
                              : null,
                        ),
                      ),
                    ],
                  ),
                  if (i < visibleSubmissions.length - 1)
                    Divider(color: context.colors.outlineVariant),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _NotSubmittedTab extends ConsumerWidget {
  const _NotSubmittedTab({required this.pad});

  final double pad;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(teacherHomeworkNonSubmittersProvider);
    return async.when(
      loading: () => const AksharaLoadingState(),
      error: (_, __) => const AksharaErrorState(
        message: 'Unable to load the not-submitted list.',
      ),
      data: (students) {
        if (students.isEmpty) {
          return const AksharaEmptyState(
            message: 'Everyone has submitted. ',
            icon: Icons.task_alt_outlined,
            compact: true,
          );
        }
        return ListView.separated(
          padding: EdgeInsets.fromLTRB(
            pad,
            AksharaSpacing.s3,
            pad,
            AksharaSpacing.s6,
          ),
          itemCount: students.length,
          separatorBuilder: (context, _) =>
              Divider(color: context.colors.outlineVariant),
          itemBuilder: (context, index) {
            final student = students[index];
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_outline),
              title: Text(student.name),
              trailing: const AksharaStatusChip(
                label: 'Not submitted',
                tone: KpiAccent.warning,
                size: AksharaStatusChipSize.compact,
              ),
            );
          },
        );
      },
    );
  }
}
