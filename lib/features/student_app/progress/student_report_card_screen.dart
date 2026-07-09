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
    final data = ref.watch(studentExamsProvider);
    // QA-J-011 — student-side report-card download. Reuses the SAME shared
    // [AksharaReportExportService.shareReportCardPdf] the parent app uses; the
    // action only appears once a published report card exists for the student.
    final reportCard = ref.watch(studentReportCardProvider);

    return Scaffold(
      key: QaTestKeys.studentReportCardScreen,
      backgroundColor: context.colors.surfaceContainerLow,
      appBar: AksharaAppBar(
        titleText: 'Report Card',
        subtitle: '${data.studentName} · ${data.classLabel}',
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
      body: ListView(
        padding: const EdgeInsets.all(AksharaSpacing.s4),
        children: [
          AksharaSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Term summary', style: context.aksharaText.titleLarge),
                const SizedBox(height: AksharaSpacing.s2),
                Text(
                  'Average: ${data.averagePercent.toStringAsFixed(1)}%',
                  style: context.aksharaText.kpiValue,
                ),
              ],
            ),
          ),
          const SizedBox(height: AksharaSpacing.s4),
          const AksharaSectionHeader(title: 'Subject scores'),
          const SizedBox(height: AksharaSpacing.s3),
          for (final score in data.subjectScores)
            Padding(
              padding: const EdgeInsets.only(bottom: AksharaSpacing.s2),
              child: SubjectScoreRow(score: score),
            ),
          const SizedBox(height: AksharaSpacing.s4),
          const AksharaSectionHeader(title: 'Recent results'),
          const SizedBox(height: AksharaSpacing.s3),
          for (final result in data.examResults)
            Padding(
              padding: const EdgeInsets.only(bottom: AksharaSpacing.s2),
              child: ExamResultRow(result: result),
            ),
        ],
      ),
    );
  }
}
