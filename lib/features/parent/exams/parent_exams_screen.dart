import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import 'exam_models.dart';
import 'parent_exams_provider.dart';
import 'report_card_provider.dart';
import 'report_card_screen.dart';
import 'widgets/exam_result_row.dart';
import 'widgets/upcoming_exam_card.dart';
import '../../../theme/breakpoints.dart';

/// Parent exams module — PA-06 `PA-06-ParentExams-M`.
class ParentExamsScreen extends ConsumerWidget {
  const ParentExamsScreen({
    super.key,
    this.onNotificationsTap,
    this.onUpcomingExamTap,
    this.onExamResultTap,
  });

  final VoidCallback? onNotificationsTap;
  final void Function(ExamScheduleItem item)? onUpcomingExamTap;
  final void Function(ExamResultItem item)? onExamResultTap;

  static const double _tabletBreakpoint = AksharaBreakpoints.tabletMinWidth;
  static const double _tabletMaxContentWidth = AksharaBreakpoints.compactContentMaxWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(parentExamsFutureProvider);
    final data = ref.watch(parentExamsProvider);
    final section = ref.watch(parentExamSectionProvider);
    final isLoading =
        ref.watch(parentExamsLoadingProvider) || async.isLoading;
    final manualError = ref.watch(parentExamsErrorProvider);
    final error = async.hasError
        ? (manualError ?? 'Unable to load exam data right now.')
        : manualError;
    final isSectionEmpty = switch (section) {
      ExamSection.upcoming => data.upcomingExams.isEmpty,
      ExamSection.results => data.examResults.isEmpty,
    };

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AksharaAppBar(
        titleText: 'Exams',
        subtitle: async.hasValue
            ? '${data.childName} · ${data.childClass}'
            : null,
        unreadNotifications: async.hasValue ? data.unreadNotifications : 0,
        showAi: false,
        trailingPadding: true,
        onNotificationsTap: onNotificationsTap,
      ),
      // DS V2 P4 — premium persona canvas behind the exams content.
      body: AksharaPremiumBackground(
        showMotif: false,
        child: _buildStatefulBody(
          context: context,
          ref: ref,
          data: data,
          section: section,
          isLoading: isLoading,
          error: error,
          isSectionEmpty: isSectionEmpty,
        ),
      ),
    );
  }

  Widget _buildStatefulBody({
    required BuildContext context,
    required WidgetRef ref,
    required ParentExamsData data,
    required ExamSection section,
    required bool isLoading,
    required String? error,
    required bool isSectionEmpty,
  }) {
    if (isLoading) {
      return const AksharaLoadingState();
    }

    if (error != null) {
      return AksharaErrorState(
        message: error,
        onRetry: () {
          ref.read(parentExamsErrorProvider.notifier).state = null;
          ref.invalidate(parentExamsFutureProvider);
        },
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth >= _tabletBreakpoint;
        final horizontalPadding = isTablet
            ? AksharaSpacing.tabletMargin
            : AksharaSpacing.mobileMargin;

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isTablet ? _tabletMaxContentWidth : double.infinity,
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
                  _ExamsKpiRow(data: data),
                  const SizedBox(height: AksharaSpacing.s4),
                  _SectionSegmentedControl(
                    selected: section,
                    onChanged: (selectedSection) {
                      ref.read(parentExamSectionProvider.notifier).state =
                          selectedSection;
                    },
                  ),
                  const SizedBox(height: AksharaSpacing.s4),
                  if (isSectionEmpty)
                    _SectionEmptyState(
                      section: section,
                      onSwitchSection: () {
                        final target = section == ExamSection.upcoming
                            ? ExamSection.results
                            : ExamSection.upcoming;
                        ref.read(parentExamSectionProvider.notifier).state =
                            target;
                      },
                    )
                  else
                    _SectionContent(
                      section: section,
                      data: data,
                      onUpcomingExamTap: onUpcomingExamTap,
                      onExamResultTap: onExamResultTap,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SectionSegmentedControl extends StatelessWidget {
  const _SectionSegmentedControl({
    required this.selected,
    required this.onChanged,
  });

  final ExamSection selected;
  final void Function(ExamSection section) onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Exam section selector',
      child: SegmentedButton<ExamSection>(
        segments: [
          for (final section in ExamSection.values)
            ButtonSegment<ExamSection>(
              value: section,
              label: Text(section.label),
            ),
        ],
        selected: {selected},
        showSelectedIcon: false,
        onSelectionChanged: (selection) => onChanged(selection.first),
      ),
    );
  }
}

class _ExamsKpiRow extends StatelessWidget {
  const _ExamsKpiRow({required this.data});

  final ParentExamsData data;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: AksharaKpiCard(
              value: '${data.upcomingCount}',
              subtitle: 'Upcoming',
              accent: KpiAccent.primary,
              icon: Icons.event_note_outlined,
            ),
          ),
          const SizedBox(width: AksharaSpacing.s2),
          Expanded(
            child: AksharaKpiCard(
              value: '${data.averageScorePercent}%',
              subtitle: 'Avg score',
              accent: KpiAccent.success,
              icon: Icons.insights_outlined,
            ),
          ),
          const SizedBox(width: AksharaSpacing.s2),
          Expanded(
            child: AksharaKpiCard(
              value: '${data.resultsCount}',
              subtitle: 'Published',
              accent: KpiAccent.warning,
              icon: Icons.fact_check_outlined,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionContent extends StatelessWidget {
  const _SectionContent({
    required this.section,
    required this.data,
    this.onUpcomingExamTap,
    this.onExamResultTap,
  });

  final ExamSection section;
  final ParentExamsData data;
  final void Function(ExamScheduleItem item)? onUpcomingExamTap;
  final void Function(ExamResultItem item)? onExamResultTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AksharaSectionHeader(title: section.label, fixedHeight: false),
        const SizedBox(height: AksharaSpacing.s3),
        if (section == ExamSection.upcoming)
          Column(
            children: [
              for (var i = 0; i < data.upcomingExams.length; i++) ...[
                UpcomingExamCard(
                  item: data.upcomingExams[i],
                  onTap: onUpcomingExamTap == null
                      ? null
                      : () => onUpcomingExamTap!(data.upcomingExams[i]),
                ),
                if (i < data.upcomingExams.length - 1)
                  const SizedBox(height: AksharaSpacing.s3),
              ],
            ],
          )
        else
          Material(
            color: context.colors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AksharaSpacing.s2),
              side: BorderSide(color: context.colors.outlineVariant),
            ),
            child: Column(
              children: [
                for (var i = 0; i < data.examResults.length; i++)
                  ExamResultRow(
                    item: data.examResults[i],
                    showDivider: i < data.examResults.length - 1,
                    onTap: onExamResultTap == null
                        ? null
                        : () => onExamResultTap!(data.examResults[i]),
                  ),
              ],
            ),
          ),
        if (section == ExamSection.results) ...[
          const SizedBox(height: AksharaSpacing.s3),
          FilledButton.tonalIcon(
            key: QaTestKeys.parentReportCardButton,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ReportCardScreen(
                  provider: parentReportCardProvider,
                  schoolName: data.schoolName,
                ),
              ),
            ),
            icon: const Icon(Icons.assignment_outlined),
            label: const Text('View report card'),
          ),
        ],
      ],
    );
  }
}

class _SectionEmptyState extends StatelessWidget {
  const _SectionEmptyState({
    required this.section,
    required this.onSwitchSection,
  });

  final ExamSection section;
  final VoidCallback onSwitchSection;

  @override
  Widget build(BuildContext context) {
    final isUpcoming = section == ExamSection.upcoming;
    return AksharaEmptyState(
      icon: isUpcoming ? Icons.event_busy_outlined : Icons.assignment_outlined,
      message: isUpcoming
          ? 'No upcoming exams scheduled right now.'
          : 'No exam results are available yet.',
      actionLabel: isUpcoming ? 'View results' : 'View upcoming exams',
      onAction: onSwitchSection,
    );
  }
}
