import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../communication/teacher_teaching_context_provider.dart';
import 'homework_models.dart';
import 'teacher_homework_provider.dart';
import 'widgets/homework_submission_row.dart';
import '../../../theme/breakpoints.dart';

/// Teacher homework review — TA-04.
class TeacherHomeworkScreen extends ConsumerWidget {
  const TeacherHomeworkScreen({super.key, this.onNotificationsTap});

  final VoidCallback? onNotificationsTap;

  static const double _tabletBreakpoint = AksharaBreakpoints.tabletMinWidth;
  static const double _tabletMaxContentWidth = AksharaBreakpoints.compactContentMaxWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        unreadNotifications: 1,
        trailingPadding: true,
        onNotificationsTap: onNotificationsTap,
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

class _HomeworkBody extends ConsumerWidget {
  const _HomeworkBody({
    required this.assignment,
    required this.assignments,
  });

  final TeacherHomeworkAssignment assignment;
  final List<TeacherHomeworkAssignment> assignments;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth >=
            TeacherHomeworkScreen._tabletBreakpoint;
        final pad = isTablet
            ? AksharaSpacing.tabletMargin
            : AksharaSpacing.mobileMargin;

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth:
                  isTablet ? TeacherHomeworkScreen._tabletMaxContentWidth : double.infinity,
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
                  ),
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
                            .read(teacherHomeworkAssignmentProvider.notifier)
                            .state = value;
                      }
                    },
                  ),
                  const SizedBox(height: AksharaSpacing.s4),
                  AksharaSectionHeader(
                    title: assignment.title,
                    trailingLabel: assignment.dueLabel,
                    fixedHeight: false,
                  ),
                  const SizedBox(height: AksharaSpacing.s3),
                  Column(
                    children: [
                      for (var i = 0; i < assignment.submissions.length; i++) ...[
                        HomeworkSubmissionRow(
                          submission: assignment.submissions[i],
                          onReview: assignment.submissions[i].status ==
                                  HomeworkReviewStatus.pending
                              ? () => _showReviewSheet(
                                    context,
                                    ref,
                                    assignment.id,
                                    assignment.submissions[i],
                                  )
                              : null,
                        ),
                        if (i < assignment.submissions.length - 1)
                          Divider(color: context.colors.outlineVariant),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showReviewSheet(
    BuildContext context,
    WidgetRef ref,
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
