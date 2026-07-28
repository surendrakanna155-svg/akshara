import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/reports/akshara_report_export_service.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../exams/report_card_provider.dart';
import '../exams/student_exams_provider.dart';
import '../exams/widgets/exam_result_row.dart';
import '../exams/widgets/subject_score_row.dart';

/// Neutral fallback when the real per-tenant school name is momentarily
/// unavailable (e.g. the exams snapshot hasn't resolved yet) — never a
/// hardcoded specific school's name.
const String _reportCardSchoolNameFallback = 'School';

/// ST-06 — Term report card synthesized from synced exam results.
class StudentReportCardScreen extends ConsumerWidget {
  const StudentReportCardScreen({super.key, this.onNotificationsTap});

  final VoidCallback? onNotificationsTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Honest state — the exams snapshot is asynchronous, so loading and error
    // are first-class here exactly as on the sibling ST-05 exams screen. A
    // failed fetch must NEVER render as a populated-looking report card.
    final async = ref.watch(studentExamsFutureProvider);
    final data = ref.watch(studentExamsProvider);
    final isLoading = ref.watch(studentExamsLoadingProvider) || async.isLoading;
    final hasError = ref.watch(studentExamsErrorProvider) || async.hasError;

    // The term average is DERIVED from published results. With nothing
    // published it is unknown, not 0.0% — so it is not rendered at all.
    final hasPublishedResults =
        data.examResults.isNotEmpty || data.subjectScores.isNotEmpty;

    // QA-J-011 — student-side report-card download. Reuses the SAME shared
    // [AksharaReportExportService.shareReportCardPdf] the parent app uses; the
    // action only appears once a published report card exists for the student.
    final reportCard = ref.watch(studentReportCardProvider);

    return Scaffold(
      key: QaTestKeys.studentReportCardScreen,
      backgroundColor: Colors.transparent,
      appBar: AksharaAppBar(
        titleText: 'Report Card',
        subtitle:
            async.hasValue ? '${data.studentName} · ${data.classLabel}' : null,
        onNotificationsTap: onNotificationsTap,
        additionalActions: [
          if (reportCard != null)
            IconButton(
              key: QaTestKeys.studentReportCardExportButton,
              tooltip: 'Export / share PDF',
              icon: const Icon(Icons.ios_share_outlined),
              onPressed: () => ref
                  .read(aksharaReportExportServiceProvider)
                  .shareReportCardPdf(
                    card: reportCard,
                    schoolName: data.schoolName.isNotEmpty
                        ? data.schoolName
                        : _reportCardSchoolNameFallback,
                  ),
            ),
        ],
      ),
      // DS V2 P4 — premium persona canvas behind the report-card content.
      body: AksharaPremiumBackground(
        showMotif: false,
        child: isLoading
            ? const AksharaLoadingState(semanticLabel: 'Loading report card')
            : hasError
                ? AksharaErrorState(
                    message: 'Unable to load your report card right now.',
                    onRetry: () {
                      ref.read(studentExamsErrorProvider.notifier).state =
                          false;
                      ref.invalidate(studentExamsFutureProvider);
                    },
                  )
                : !hasPublishedResults
                    // Nothing measured → no average, no scores, no praise.
                    ? const AksharaEmptyState(
                        message: 'No exam results published yet. Your term '
                            'average appears once your school publishes marks.',
                        icon: Icons.grading_outlined,
                      )
                    : ListView(
                        padding: const EdgeInsets.all(AksharaSpacing.s4),
                        children: [
                          AksharaSurfaceCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Term summary',
                                  style: context.aksharaText.titleLarge,
                                ),
                                const SizedBox(height: AksharaSpacing.s2),
                                Text(
                                  'Average: '
                                  '${data.averagePercent.toStringAsFixed(1)}%',
                                  style: context.aksharaText.kpiValue,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AksharaSpacing.s4),
                          const AksharaSectionHeader(title: 'Subject scores'),
                          const SizedBox(height: AksharaSpacing.s3),
                          if (data.subjectScores.isEmpty)
                            const AksharaSectionEmpty(
                              message: 'No subject scores published yet.',
                              icon: Icons.insights_outlined,
                            )
                          else
                            for (final score in data.subjectScores)
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AksharaSpacing.s2,
                                ),
                                child: SubjectScoreRow(score: score),
                              ),
                          const SizedBox(height: AksharaSpacing.s4),
                          const AksharaSectionHeader(title: 'Recent results'),
                          const SizedBox(height: AksharaSpacing.s3),
                          if (data.examResults.isEmpty)
                            const AksharaSectionEmpty(
                              message: 'No exam results published yet.',
                              icon: Icons.grading_outlined,
                            )
                          else
                            for (final result in data.examResults)
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AksharaSpacing.s2,
                                ),
                                child: ExamResultRow(result: result),
                              ),
                        ],
                      ),
      ),
    );
  }
}
