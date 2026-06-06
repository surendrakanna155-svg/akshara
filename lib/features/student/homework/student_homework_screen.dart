import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import 'student_homework_provider.dart';
import 'widgets/homework_filter_bar.dart';
import 'widgets/homework_list_row.dart';

/// Student homework — ST-04.
class StudentHomeworkScreen extends ConsumerWidget {
  const StudentHomeworkScreen({super.key, this.onNotificationsTap});

  final VoidCallback? onNotificationsTap;

  static const double _tabletBreakpoint = 768;
  static const double _tabletMaxContentWidth = 480;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(studentHomeworkProvider);
    final filter = ref.watch(studentHomeworkFilterProvider);
    final isLoading = ref.watch(studentHomeworkLoadingProvider);
    final hasError = ref.watch(studentHomeworkErrorProvider);

    return Scaffold(
      backgroundColor: context.colors.surfaceContainerLow,
      appBar: AksharaAppBar(
        titleText: 'Homework',
        subtitle: '${data.studentName} · ${data.classLabel}',
        unreadNotifications: data.unreadNotifications,
        trailingPadding: true,
        onNotificationsTap: onNotificationsTap,
      ),
      body: isLoading
          ? const AksharaLoadingState(semanticLabel: 'Loading homework')
          : hasError
              ? AksharaErrorState(
                  message: 'Unable to load homework right now.',
                  onRetry: () => ref
                      .read(studentHomeworkErrorProvider.notifier)
                      .state = false,
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final isTablet =
                        constraints.maxWidth >= _tabletBreakpoint;
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
                        child: SingleChildScrollView(
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
                                    .read(studentHomeworkFilterProvider.notifier)
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
                                    for (var i = 0; i < data.items.length; i++) ...[
                                      HomeworkListRow(item: data.items[i]),
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
                    );
                  },
                ),
    );
  }
}
