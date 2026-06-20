import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../parent/exams/report_card_screen.dart';
import 'exam_models.dart';
import 'report_card_provider.dart';
import 'student_exams_provider.dart';
import 'widgets/exam_result_row.dart';
import 'widgets/subject_score_row.dart';
import '../../../theme/breakpoints.dart';

/// Student exams and results — ST-05.
class StudentExamsScreen extends ConsumerWidget {
  const StudentExamsScreen({super.key, this.onNotificationsTap});

  final VoidCallback? onNotificationsTap;

  static const double _tabletBreakpoint = AksharaBreakpoints.tabletMinWidth;
  static const double _tabletMaxContentWidth = AksharaBreakpoints.compactContentMaxWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(studentExamsProvider);
    final section = ref.watch(studentExamSectionProvider);
    final isLoading = ref.watch(studentExamsLoadingProvider);
    final hasError = ref.watch(studentExamsErrorProvider);

    return Scaffold(
      backgroundColor: context.colors.surfaceContainerLow,
      appBar: AksharaAppBar(
        titleText: 'Exams',
        subtitle: '${data.studentName} · ${data.classLabel}',
        unreadNotifications: data.unreadNotifications,
        trailingPadding: true,
        onNotificationsTap: onNotificationsTap,
      ),
      body: isLoading
          ? const AksharaLoadingState(semanticLabel: 'Loading exams')
          : hasError
              ? AksharaErrorState(
                  message: 'Unable to load exam data right now.',
                  onRetry: () =>
                      ref.read(studentExamsErrorProvider.notifier).state =
                          false,
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
                                        value: '${data.averagePercent}%',
                                        subtitle: 'Class average',
                                        accent: KpiAccent.primary,
                                        icon: Icons.trending_up_outlined,
                                      ),
                                    ),
                                    const SizedBox(width: AksharaSpacing.s2),
                                    Expanded(
                                      child: AksharaKpiCard(
                                        value: '${data.upcomingExams.length}',
                                        subtitle: 'Upcoming',
                                        accent: KpiAccent.warning,
                                        icon: Icons.event_outlined,
                                      ),
                                    ),
                                    const SizedBox(width: AksharaSpacing.s2),
                                    Expanded(
                                      child: AksharaKpiCard(
                                        value: '${data.examResults.length}',
                                        subtitle: 'Results',
                                        accent: KpiAccent.success,
                                        icon: Icons.emoji_events_outlined,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AksharaSpacing.s4),
                              SegmentedButton<StudentExamSection>(
                                segments: [
                                  for (final s in StudentExamSection.values)
                                    ButtonSegment(
                                      value: s,
                                      label: Text(s.label),
                                    ),
                                ],
                                selected: {section},
                                onSelectionChanged: (value) => ref
                                    .read(studentExamSectionProvider.notifier)
                                    .state = value.first,
                              ),
                              const SizedBox(height: AksharaSpacing.s4),
                              switch (section) {
                                StudentExamSection.upcoming =>
                                  _UpcomingSection(exams: data.upcomingExams),
                                StudentExamSection.results => _ResultsSection(
                                    results: data.examResults,
                                    subjectScores: data.subjectScores,
                                  ),
                              },
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

class _UpcomingSection extends StatelessWidget {
  const _UpcomingSection({required this.exams});

  final List<StudentUpcomingExam> exams;

  @override
  Widget build(BuildContext context) {
    if (exams.isEmpty) {
      return const AksharaEmptyState(
        message: 'No upcoming exams scheduled.',
        icon: Icons.event_available_outlined,
        compact: true,
      );
    }

    final colors = context.colors;
    final text = context.aksharaText;

    return Column(
      children: [
        for (var i = 0; i < exams.length; i++) ...[
          Semantics(
            container: true,
            label:
                '${exams[i].title}, ${exams[i].dateLabel}, ${exams[i].venueLabel}',
            child: Material(
              color: colors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: colors.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AksharaSpacing.s4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exams[i].title,
                      style: text.titleSmall.copyWith(color: colors.onSurface),
                    ),
                    const SizedBox(height: AksharaSpacing.s1),
                    Text(
                      '${exams[i].subject} · ${exams[i].dateLabel} · ${exams[i].timeLabel}',
                      style: text.bodySmall.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      exams[i].venueLabel,
                      style: text.bodySmall.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (i < exams.length - 1) const SizedBox(height: AksharaSpacing.s2),
        ],
      ],
    );
  }
}

class _ResultsSection extends StatelessWidget {
  const _ResultsSection({
    required this.results,
    required this.subjectScores,
  });

  final List<StudentExamResult> results;
  final List<SubjectScore> subjectScores;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty && subjectScores.isEmpty) {
      return const AksharaEmptyState(
        message: 'No exam results published yet.',
        icon: Icons.grading_outlined,
        compact: true,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AksharaSectionHeader(
          title: 'Recent results',
          fixedHeight: false,
          spacingBelow: AksharaSpacing.s2,
        ),
        for (var i = 0; i < results.length; i++) ...[
          ExamResultRow(result: results[i]),
          if (i < results.length - 1) const SizedBox(height: AksharaSpacing.s2),
        ],
        if (results.isNotEmpty) ...[
          const SizedBox(height: AksharaSpacing.s3),
          FilledButton.tonalIcon(
            key: QaTestKeys.studentReportCardButton,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    ReportCardScreen(provider: studentReportCardProvider),
              ),
            ),
            icon: const Icon(Icons.assignment_outlined),
            label: const Text('View report card'),
          ),
        ],
        const SizedBox(height: AksharaSpacing.s4),
        const AksharaSectionHeader(
          title: 'Subject-wise scores',
          fixedHeight: false,
          spacingBelow: AksharaSpacing.s2,
        ),
        for (var i = 0; i < subjectScores.length; i++) ...[
          SubjectScoreRow(score: subjectScores[i]),
          if (i < subjectScores.length - 1)
            const SizedBox(height: AksharaSpacing.s2),
        ],
      ],
    );
  }
}
