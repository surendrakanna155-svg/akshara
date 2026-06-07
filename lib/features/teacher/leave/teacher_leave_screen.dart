import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/widgets.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import 'leave_models.dart';
import 'teacher_leave_provider.dart';

/// Teacher leave requests — TA-07.
class TeacherLeaveScreen extends ConsumerWidget {
  const TeacherLeaveScreen({super.key, this.onNotificationsTap});

  final VoidCallback? onNotificationsTap;

  static const double _tabletBreakpoint = 768;
  static const double _tabletMaxContentWidth = 480;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final section = ref.watch(teacherLeaveSectionProvider);
    final balance = ref.watch(teacherLeaveBalanceProvider);
    final history = ref.watch(teacherLeaveHistoryProvider);
    final draft = ref.watch(teacherLeaveApplyDraftProvider);
    final isLoading = ref.watch(teacherLeaveLoadingProvider);
    final hasError = ref.watch(teacherLeaveErrorProvider);

    return Scaffold(
      backgroundColor: context.colors.surfaceContainerLow,
      appBar: AksharaAppBar(
        titleText: 'Leave',
        subtitle: 'Priya Sharma',
        unreadNotifications: 1,
        trailingPadding: true,
        onNotificationsTap: onNotificationsTap,
      ),
      body: isLoading
          ? const AksharaLoadingState()
          : hasError
              ? AksharaErrorState(
                  message: 'Unable to load leave data.',
                  onRetry: () =>
                      ref.read(teacherLeaveErrorProvider.notifier).state = false,
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
                              _BalanceRow(balance: balance),
                              const SizedBox(height: AksharaSpacing.s4),
                              SegmentedButton<TeacherLeaveSection>(
                                segments: const [
                                  ButtonSegment(
                                    value: TeacherLeaveSection.history,
                                    label: Text('History'),
                                  ),
                                  ButtonSegment(
                                    value: TeacherLeaveSection.apply,
                                    label: Text('Apply leave'),
                                  ),
                                ],
                                selected: {section},
                                showSelectedIcon: false,
                                onSelectionChanged: (v) => ref
                                    .read(teacherLeaveSectionProvider.notifier)
                                    .state = v.first,
                              ),
                              const SizedBox(height: AksharaSpacing.s4),
                              if (section == TeacherLeaveSection.apply)
                                _ApplyForm(draft: draft)
                              else if (history.isEmpty)
                                const AksharaEmptyState(
                                  message: 'No leave requests yet.',
                                  compact: true,
                                )
                              else
                                Column(
                                  children: [
                                    for (var i = 0; i < history.length; i++) ...[
                                      _LeaveCard(request: history[i]),
                                      if (i < history.length - 1)
                                        const SizedBox(
                                          height: AksharaSpacing.s3,
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

class _BalanceRow extends StatelessWidget {
  const _BalanceRow({required this.balance});
  final LeaveBalance balance;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: AksharaKpiCard(
              value: '${balance.casualRemaining}',
              subtitle: 'Casual',
              accent: KpiAccent.primary,
            ),
          ),
          const SizedBox(width: AksharaSpacing.s2),
          Expanded(
            child: AksharaKpiCard(
              value: '${balance.sickRemaining}',
              subtitle: 'Sick',
              accent: KpiAccent.warning,
            ),
          ),
          const SizedBox(width: AksharaSpacing.s2),
          Expanded(
            child: AksharaKpiCard(
              value: '${balance.earnedRemaining}',
              subtitle: 'Earned',
              accent: KpiAccent.success,
            ),
          ),
        ],
      ),
    );
  }
}

class _ApplyForm extends ConsumerWidget {
  const _ApplyForm({required this.draft});
  final TeacherLeaveApplyDraft draft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          initialValue: draft.typeLabel,
          decoration: const InputDecoration(
            labelText: 'Leave type',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'Casual leave', child: Text('Casual leave')),
            DropdownMenuItem(value: 'Sick leave', child: Text('Sick leave')),
            DropdownMenuItem(value: 'Earned leave', child: Text('Earned leave')),
          ],
          onChanged: (v) {
            if (v != null) {
              ref.read(teacherLeaveApplyDraftProvider.notifier).state =
                  draft.copyWith(typeLabel: v);
            }
          },
        ),
        const SizedBox(height: AksharaSpacing.s3),
        TextField(
          decoration: const InputDecoration(
            labelText: 'From date',
            border: OutlineInputBorder(),
          ),
          onChanged: (v) => ref
              .read(teacherLeaveApplyDraftProvider.notifier)
              .state = draft.copyWith(fromDateLabel: v),
        ),
        const SizedBox(height: AksharaSpacing.s3),
        TextField(
          decoration: const InputDecoration(
            labelText: 'To date',
            border: OutlineInputBorder(),
          ),
          onChanged: (v) => ref
              .read(teacherLeaveApplyDraftProvider.notifier)
              .state = draft.copyWith(toDateLabel: v),
        ),
        const SizedBox(height: AksharaSpacing.s3),
        TextField(
          minLines: 3,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Reason',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
          onChanged: (v) => ref
              .read(teacherLeaveApplyDraftProvider.notifier)
              .state = draft.copyWith(reason: v),
        ),
        const SizedBox(height: AksharaSpacing.s4),
        FilledButton(
          onPressed: draft.isValid
              ? () async {
                  final ok = await submitTeacherLeave(ref);
                  if (!context.mounted) return;
                  if (ok) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Leave request submitted (mock).'),
                      ),
                    );
                  }
                }
              : null,
          child: const Text('Submit leave request'),
        ),
      ],
    );
  }
}

class _LeaveCard extends StatelessWidget {
  const _LeaveCard({required this.request});
  final TeacherLeaveRequest request;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;
    final tone = switch (request.status) {
      TeacherLeaveStatus.pending => KpiAccent.warning,
      TeacherLeaveStatus.approved => KpiAccent.success,
      TeacherLeaveStatus.rejected => KpiAccent.error,
    };

    return Semantics(
      container: true,
      label:
          '${request.typeLabel} ${request.fromDateLabel} to ${request.toDateLabel}',
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AksharaRadius.card,
          side: BorderSide(color: colors.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${request.fromDateLabel} – ${request.toDateLabel}',
                      style: text.titleSmall,
                    ),
                  ),
                  AksharaStatusChip(
                    label: request.status.label,
                    tone: tone,
                    size: AksharaStatusChipSize.compact,
                  ),
                ],
              ),
              Text(
                request.typeLabel,
                style: text.bodySmall.copyWith(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: AksharaSpacing.s2),
              Text(request.reason, style: text.bodyMedium),
              const SizedBox(height: AksharaSpacing.s3),
              for (final step in request.timeline)
                Padding(
                  padding: const EdgeInsets.only(bottom: AksharaSpacing.s2),
                  child: Row(
                    children: [
                      Icon(
                        step.isComplete
                            ? Icons.check_circle_outline
                            : Icons.radio_button_unchecked,
                        size: 16,
                        color: step.isComplete
                            ? context.akshara.success
                            : colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: AksharaSpacing.s2),
                      Expanded(
                        child: Text(
                          '${step.label} · ${step.dateLabel}',
                          style: text.bodySmall,
                        ),
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
