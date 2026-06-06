import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import 'homework_models.dart';
import 'parent_homework_provider.dart';
import 'widgets/homework_filter_bar.dart';
import 'widgets/homework_list_row.dart';

/// Parent homework module screen — PA-05.
class ParentHomeworkScreen extends ConsumerWidget {
  const ParentHomeworkScreen({
    super.key,
    this.onNotificationsTap,
  });

  final VoidCallback? onNotificationsTap;

  static const double _tabletBreakpoint = 768;
  static const double _tabletMaxContentWidth = 480;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(parentHomeworkDataProvider);
    final selectedFilter = ref.watch(homeworkFilterProvider);
    final isLoading = ref.watch(parentHomeworkLoadingProvider);
    final hasError = ref.watch(parentHomeworkErrorProvider);

    return Scaffold(
      backgroundColor: context.colors.surfaceContainerLow,
      appBar: AksharaAppBar(
        titleText: 'Homework',
        subtitle: '${data.childName} · ${data.childClass}',
        unreadNotifications: data.unreadNotifications,
        showAi: true,
        trailingPadding: true,
        onAiTap: () {},
        onNotificationsTap: onNotificationsTap,
      ),
      body: isLoading
          ? const AksharaLoadingState()
          : hasError
              ? AksharaErrorState(
                  message: 'Unable to load homework right now.',
                  onRetry: () => ref
                      .read(parentHomeworkErrorProvider.notifier)
                      .state = false,
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
                              _HomeworkKpiStrip(data: data),
                              const SizedBox(height: AksharaSpacing.s4),
                              HomeworkFilterBar(
                                selectedFilter: selectedFilter,
                                onFilterChanged: (filter) => ref
                                    .read(homeworkFilterProvider.notifier)
                                    .state = filter,
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
                                      HomeworkListRow(item: data.items[i]),
                                      if (i < data.items.length - 1)
                                        const SizedBox(
                                            height: AksharaSpacing.s2),
                                    ],
                                  ],
                                ),
                              const SizedBox(height: AksharaSpacing.s4),
                              AksharaInsightCard(
                                message: data.insightMessage,
                                actionLabel: data.insightActionLabel,
                                onAction: () {},
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

class _HomeworkKpiStrip extends StatelessWidget {
  const _HomeworkKpiStrip({required this.data});

  final ParentHomeworkData data;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
              icon: Icons.check_circle_outline,
            ),
          ),
          const SizedBox(width: AksharaSpacing.s2),
          Expanded(
            child: AksharaKpiCard(
              value: '${data.overdueCount}',
              subtitle: 'Overdue',
              accent: KpiAccent.error,
              icon: Icons.warning_amber_rounded,
            ),
          ),
        ],
      ),
    );
  }
}
