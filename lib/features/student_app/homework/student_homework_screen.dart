import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../dashboard/student_dashboard_provider.dart';
import 'homework_models.dart';
import 'student_homework_provider.dart';
import 'widgets/homework_filter_bar.dart';
import 'widgets/homework_list_row.dart';
import '../../../theme/breakpoints.dart';

/// Student homework — ST-04.
class StudentHomeworkScreen extends ConsumerWidget {
  const StudentHomeworkScreen({super.key, this.onNotificationsTap});

  final VoidCallback? onNotificationsTap;

  static const double _tabletBreakpoint = AksharaBreakpoints.tabletMinWidth;
  static const double _tabletMaxContentWidth =
      AksharaBreakpoints.compactContentMaxWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncHomework = ref.watch(studentHomeworkFutureProvider);
    final asyncDash = ref.watch(studentDashboardFutureProvider);
    final data = ref.watch(studentHomeworkProvider);
    final filter = ref.watch(studentHomeworkFilterProvider);
    final isLoading = ref.watch(studentHomeworkLoadingProvider) ||
        asyncHomework.isLoading ||
        asyncDash.isLoading;
    final hasError = ref.watch(studentHomeworkErrorProvider) ||
        asyncHomework.hasError ||
        asyncDash.hasError;
    final identityResolved = asyncDash.hasValue && data.studentName.isNotEmpty;

    return Scaffold(
      backgroundColor: context.colors.surfaceContainerLow,
      appBar: AksharaAppBar(
        titleText: 'Homework',
        subtitle: identityResolved
            ? '${data.studentName} · ${data.classLabel}'
            : null,
        unreadNotifications: asyncDash.hasValue ? data.unreadNotifications : 0,
        trailingPadding: true,
        onNotificationsTap: onNotificationsTap,
      ),
      body: isLoading
          ? const AksharaLoadingState(semanticLabel: 'Loading homework')
          : hasError
              ? AksharaErrorState(
                  message: 'Unable to load homework right now.',
                  onRetry: () {
                    ref.read(studentHomeworkErrorProvider.notifier).state =
                        false;
                    ref.invalidate(studentHomeworkFutureProvider);
                  },
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final isTablet = constraints.maxWidth >= _tabletBreakpoint;
                    final horizontalPadding = isTablet
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
                          onRefresh: () async =>
                              ref.invalidate(studentHomeworkFutureProvider),
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(
                              horizontalPadding,
                              AksharaSpacing.s4,
                              horizontalPadding,
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
                                          value: '${data.pendingCount}',
                                          subtitle: 'Pending',
                                          accent: KpiAccent.warning,
                                          icon: Icons.pending_actions_outlined,
                                        ),
                                      ),
                                      const SizedBox(width: AksharaSpacing.s2),
                                      Expanded(
                                        child: AksharaKpiCard(
                                          value: '${data.submittedCount}',
                                          subtitle: 'Submitted',
                                          accent: KpiAccent.success,
                                          icon: Icons.task_alt_outlined,
                                        ),
                                      ),
                                      const SizedBox(width: AksharaSpacing.s2),
                                      Expanded(
                                        child: AksharaKpiCard(
                                          value: '${data.overdueCount}',
                                          subtitle: 'Overdue',
                                          accent: KpiAccent.error,
                                          icon: Icons.warning_amber_outlined,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: AksharaSpacing.s4),
                                HomeworkFilterBar(
                                  selectedFilter: filter,
                                  onFilterChanged: (value) => ref
                                      .read(studentHomeworkFilterProvider
                                          .notifier)
                                      .state = value,
                                ),
                                const SizedBox(height: AksharaSpacing.s3),
                                if (data.items.isEmpty)
                                  const AksharaEmptyState(
                                    message: 'No homework in this filter.',
                                    icon: Icons.assignment_turned_in_outlined,
                                    compact: true,
                                  )
                                else
                                  Column(
                                    children: [
                                      for (var i = 0;
                                          i < data.items.length;
                                          i++) ...[
                                        HomeworkListRow(
                                          item: data.items[i],
                                          onSubmit: data.items[i]
                                                          .effectiveStatus ==
                                                      StudentHomeworkStatus
                                                          .pending ||
                                                  data.items[i]
                                                          .effectiveStatus ==
                                                      StudentHomeworkStatus
                                                          .overdue
                                              ? () => _showSubmitSheet(
                                                    context,
                                                    ref,
                                                    data.items[i],
                                                  )
                                              : null,
                                        ),
                                        if (i < data.items.length - 1)
                                          const SizedBox(
                                            height: AksharaSpacing.s2,
                                          ),
                                      ],
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  /// HWK-7 — the submit sheet lets a student add an OPTIONAL note + attachment
  /// reference (a label/URL, not a real uploaded file — no homework storage
  /// bucket yet) before handing in. Both persist onto the submission so the
  /// teacher review and parent view can surface them.
  void _showSubmitSheet(
    BuildContext context,
    WidgetRef ref,
    StudentHomeworkItem item,
  ) {
    final noteController = TextEditingController();
    final attachmentController = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          AksharaSpacing.s4,
          AksharaSpacing.s2,
          AksharaSpacing.s4,
          MediaQuery.paddingOf(sheetContext).bottom + AksharaSpacing.s4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Submit ${item.title}',
                style: sheetContext.aksharaText.titleMedium),
            const SizedBox(height: AksharaSpacing.s3),
            TextField(
              key: QaTestKeys.studentHomeworkNoteField,
              controller: noteController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                hintText: 'Anything the teacher should know',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AksharaSpacing.s3),
            TextField(
              key: QaTestKeys.studentHomeworkAttachmentField,
              controller: attachmentController,
              decoration: const InputDecoration(
                labelText: 'Attachment reference (optional)',
                hintText: 'e.g. answer photo link or file name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AksharaSpacing.s4),
            FilledButton(
              key: QaTestKeys.studentHomeworkSubmitConfirmButton,
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(sheetContext);
                final ok = await submitStudentHomework(
                  ref,
                  item.id,
                  notes: noteController.text,
                  attachmentLabel: attachmentController.text,
                );
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      ok ? 'Homework submitted.' : 'Could not submit homework.',
                    ),
                  ),
                );
              },
              child: const Text('Submit homework'),
            ),
          ],
        ),
      ),
    );
  }
}
