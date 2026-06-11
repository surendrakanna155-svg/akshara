import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import 'leave_models.dart';
import 'parent_leave_provider.dart';
import 'widgets/leave_apply_form.dart';
import 'widgets/leave_request_row.dart';

/// Parent leave requests — PA-12.
class ParentLeaveScreen extends ConsumerWidget {
  const ParentLeaveScreen({
    super.key,
    this.onNotificationsTap,
  });

  final VoidCallback? onNotificationsTap;

  static const double _tabletBreakpoint = 768;
  static const double _tabletMaxContentWidth = 480;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(parentLeaveDataProvider);
    final section = ref.watch(parentLeaveSectionProvider);
    final isLoading = ref.watch(parentLeaveLoadingProvider);
    final hasError = ref.watch(parentLeaveErrorProvider);
    final isSubmitting = ref.watch(parentLeaveSubmittingProvider);

    return Scaffold(
      backgroundColor: context.colors.surfaceContainerLow,
      appBar: AksharaAppBar(
        titleText: 'Leave Requests',
        subtitle: '${data.childName} · ${data.childClass}',
        unreadNotifications: data.unreadNotifications,
        showAi: false,
        trailingPadding: true,
        onAiTap: () {},
        onNotificationsTap: onNotificationsTap,
      ),
      body: isLoading
          ? const AksharaLoadingState(semanticLabel: 'Loading leave requests')
          : hasError
              ? AksharaErrorState(
                  message: 'Unable to load leave requests right now.',
                  onRetry: () =>
                      ref.read(parentLeaveErrorProvider.notifier).state = false,
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
                              _LeaveKpiRow(data: data),
                              const SizedBox(height: AksharaSpacing.s4),
                              _LeaveSectionControl(
                                selected: section,
                                onChanged: (value) => ref
                                    .read(parentLeaveSectionProvider.notifier)
                                    .state = value,
                              ),
                              const SizedBox(height: AksharaSpacing.s4),
                              if (section == LeaveScreenSection.history)
                                _LeaveHistorySection(history: data.history)
                              else
                                LeaveApplyForm(
                                  isSubmitting: isSubmitting,
                                  onSubmit: () async {
                                    await submitLeaveApplication(ref);
                                  },
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

class _LeaveKpiRow extends StatelessWidget {
  const _LeaveKpiRow({required this.data});

  final ParentLeaveData data;

  @override
  Widget build(BuildContext context) {
    final approved = data.history
        .where((item) => item.status == LeaveStatus.approved)
        .length;

    return SizedBox(
      height: 88,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: AksharaKpiCard(
              value: '${data.history.length}',
              subtitle: 'Total',
              accent: KpiAccent.primary,
              icon: Icons.event_note_outlined,
            ),
          ),
          const SizedBox(width: AksharaSpacing.s2),
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
              value: '$approved',
              subtitle: 'Approved',
              accent: KpiAccent.success,
              icon: Icons.check_circle_outline,
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaveSectionControl extends StatelessWidget {
  const _LeaveSectionControl({
    required this.selected,
    required this.onChanged,
  });

  final LeaveScreenSection selected;
  final ValueChanged<LeaveScreenSection> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Leave section selector',
      child: SegmentedButton<LeaveScreenSection>(
        segments: const [
          ButtonSegment(
            value: LeaveScreenSection.history,
            label: Text('History'),
          ),
          ButtonSegment(
            value: LeaveScreenSection.apply,
            label: Text('Apply leave'),
          ),
        ],
        selected: {selected},
        showSelectedIcon: false,
        onSelectionChanged: (selection) => onChanged(selection.first),
      ),
    );
  }
}

class _LeaveHistorySection extends StatelessWidget {
  const _LeaveHistorySection({required this.history});

  final List<LeaveRequest> history;

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return const AksharaEmptyState(
        message: 'No leave requests submitted yet.',
        icon: Icons.beach_access_outlined,
        compact: true,
      );
    }

    return Column(
      children: [
        for (var i = 0; i < history.length; i++) ...[
          LeaveRequestRow(
            request: history[i],
            initiallyExpanded: i == 0,
          ),
          if (i < history.length - 1)
            const SizedBox(height: AksharaSpacing.s3),
        ],
      ],
    );
  }
}
