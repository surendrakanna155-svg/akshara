import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/premium_tokens.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../../theme/typography.dart';
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
  static const double _tabletMaxContentWidth =
      AksharaBreakpoints.compactContentMaxWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(studentExamsFutureProvider);
    final data = ref.watch(studentExamsProvider);
    final section = ref.watch(studentExamSectionProvider);
    final isLoading = ref.watch(studentExamsLoadingProvider) || async.isLoading;
    final hasError = ref.watch(studentExamsErrorProvider) || async.hasError;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AksharaAppBar(
        titleText: 'Exams',
        subtitle:
            async.hasValue ? '${data.studentName} · ${data.classLabel}' : null,
        unreadNotifications: async.hasValue ? data.unreadNotifications : 0,
        trailingPadding: true,
        onNotificationsTap: onNotificationsTap,
      ),
      // DS V2 P4 — premium persona canvas behind the exams content.
      body: AksharaPremiumBackground(
        showMotif: false,
        child: isLoading
            ? const AksharaLoadingState(semanticLabel: 'Loading exams')
            : hasError
                ? AksharaErrorState(
                    message: 'Unable to load exam data right now.',
                    onRetry: () {
                      ref.read(studentExamsErrorProvider.notifier).state =
                          false;
                      ref.invalidate(studentExamsFutureProvider);
                    },
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
                                _ExamsSummaryCard(
                                  averagePercent: data.averagePercent,
                                  upcomingCount: data.upcomingExams.length,
                                  resultsCount: data.examResults.length,
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
                                      schoolName: data.schoolName,
                                    ),
                                },
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

/// ST-05 exams summary — DS V2 Phase 4 flagship: the class-average % as a
/// signature persona-accent progress **ring**, with upcoming-exam and result
/// counts as adjacent stats. Same three metrics as the old three-up KPI strip.
class _ExamsSummaryCard extends StatelessWidget {
  const _ExamsSummaryCard({
    required this.averagePercent,
    required this.upcomingCount,
    required this.resultsCount,
  });

  final int averagePercent;
  final int upcomingCount;
  final int resultsCount;

  @override
  Widget build(BuildContext context) {
    final premium = context.premium;
    final text = context.aksharaText;
    final colors = context.colors;
    final ext = context.akshara;

    return Semantics(
      container: true,
      label: 'Class average $averagePercent percent, '
          '$upcomingCount upcoming exams, $resultsCount results',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: premium.premiumSurface,
          borderRadius: BorderRadius.circular(AksharaRadius.xl),
          border: Border.all(color: premium.premiumBorder),
          boxShadow: premium.softShadow,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AksharaProgressRing(
                value: averagePercent / 100.0,
                size: 92,
                strokeWidth: 9,
                color: premium.brandStart,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$averagePercent%',
                      style: text.titleMedium.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        height: 1.0,
                      ),
                    ),
                    Text(
                      'Class average',
                      style: text.labelSmall.copyWith(
                        color: colors.onSurfaceVariant,
                        fontSize: 10,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AksharaSpacing.s5),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Stat(
                      value: '$upcomingCount',
                      label: 'Upcoming',
                      color: ext.warning,
                    ),
                    const SizedBox(height: AksharaSpacing.s3),
                    _Stat(
                      value: '$resultsCount',
                      label: 'Results',
                      color: ext.success,
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

class _Stat extends StatelessWidget {
  const _Stat({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: text.titleLarge
              .copyWith(
                color: color,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                height: 1.05,
              )
              .tabularFigures,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          label,
          style: text.bodySmall.copyWith(color: colors.onSurfaceVariant),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
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
    required this.schoolName,
  });

  final List<StudentExamResult> results;
  final List<SubjectScore> subjectScores;
  final String schoolName;

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
                builder: (_) => ReportCardScreen(
                  provider: studentReportCardProvider,
                  schoolName: schoolName,
                ),
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
