import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import 'homework_models.dart';
import 'parent_homework_provider.dart';
import 'widgets/homework_filter_bar.dart';
import 'widgets/homework_list_row.dart';
import '../../../theme/breakpoints.dart';

/// Parent homework module screen — PA-05.
class ParentHomeworkScreen extends ConsumerWidget {
  const ParentHomeworkScreen({
    super.key,
    this.onNotificationsTap,
  });

  final VoidCallback? onNotificationsTap;

  static const double _tabletBreakpoint = AksharaBreakpoints.tabletMinWidth;
  static const double _tabletMaxContentWidth =
      AksharaBreakpoints.compactContentMaxWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(parentHomeworkDataProvider);
    final selectedFilter = ref.watch(homeworkFilterProvider);
    final isLoading = ref.watch(parentHomeworkLoadingProvider);
    final hasError = ref.watch(parentHomeworkErrorProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AksharaAppBar(
        titleText: 'Homework',
        subtitle: '${data.childName} · ${data.childClass}',
        unreadNotifications: data.unreadNotifications,
        showAi: false,
        trailingPadding: true,
        onNotificationsTap: onNotificationsTap,
      ),
      // DS V2 P4 — premium persona canvas behind the homework content.
      body: AksharaPremiumBackground(
        showMotif: false,
        child: isLoading
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
                        child: RefreshIndicator(
                          onRefresh: () async =>
                              ref.invalidate(parentHomeworkFutureProvider),
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
                                        HomeworkListRow(
                                          item: data.items[i],
                                          onTap: () => _showHomeworkDetail(
                                            context,
                                            data.items[i],
                                          ),
                                        ),
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
                                  onAction: () => ref
                                      .read(homeworkFilterProvider.notifier)
                                      .state = HomeworkFilter.pending,
                                ),
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

  /// HWK-4 + HWK-7 — a read-only detail sheet surfacing the teacher's attachment
  /// on the assignment and (once handed in) the child's submission note +
  /// attachment reference and the teacher's grade/comment.
  void _showHomeworkDetail(BuildContext context, ParentHomeworkItem item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final text = sheetContext.aksharaText;
        final colors = sheetContext.colors;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            AksharaSpacing.s4,
            AksharaSpacing.s2,
            AksharaSpacing.s4,
            MediaQuery.paddingOf(sheetContext).bottom + AksharaSpacing.s4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.subject,
                  style: text.labelMedium.copyWith(color: colors.primary)),
              const SizedBox(height: AksharaSpacing.s1),
              Text(item.title, style: text.titleMedium),
              const SizedBox(height: AksharaSpacing.s1),
              Text(item.dueLabel,
                  style:
                      text.bodySmall.copyWith(color: colors.onSurfaceVariant)),
              if (item.hasTeacherAttachment) ...[
                const SizedBox(height: AksharaSpacing.s3),
                _DetailLine(
                  icon: Icons.attach_file,
                  label: 'Teacher attachment',
                  value: item.attachmentRef != null
                      ? '${item.attachmentLabel} · ${item.attachmentRef}'
                      : item.attachmentLabel!,
                ),
              ],
              if ((item.submissionNote ?? '').isNotEmpty) ...[
                const SizedBox(height: AksharaSpacing.s3),
                _DetailLine(
                  icon: Icons.note_outlined,
                  label: 'Child note',
                  value: item.submissionNote!,
                ),
              ],
              if ((item.submissionAttachmentLabel ?? '').isNotEmpty) ...[
                const SizedBox(height: AksharaSpacing.s3),
                _DetailLine(
                  icon: Icons.upload_file_outlined,
                  label: 'Child attachment',
                  value: item.submissionAttachmentLabel!,
                ),
              ],
              if (item.isReviewed) ...[
                const SizedBox(height: AksharaSpacing.s3),
                _DetailLine(
                  icon: Icons.grade_outlined,
                  label: 'Grade',
                  value:
                      '${item.reviewGrade}${(item.reviewComment ?? '').isNotEmpty ? ' — ${item.reviewComment}' : ''}',
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    final colors = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: colors.primary),
        const SizedBox(width: AksharaSpacing.s2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style:
                      text.labelSmall.copyWith(color: colors.onSurfaceVariant)),
              const SizedBox(height: 2),
              Text(value, style: text.bodyMedium),
            ],
          ),
        ),
      ],
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
