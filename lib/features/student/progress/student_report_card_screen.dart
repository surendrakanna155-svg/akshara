import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../exams/student_exams_provider.dart';
import '../exams/widgets/exam_result_row.dart';
import '../exams/widgets/subject_score_row.dart';

/// ST-06 — Term report card synthesized from synced exam results.
class StudentReportCardScreen extends ConsumerWidget {
  const StudentReportCardScreen({super.key, this.onNotificationsTap});

  final VoidCallback? onNotificationsTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(studentExamsProvider);

    return Scaffold(
      key: QaTestKeys.studentReportCardScreen,
      backgroundColor: context.colors.surfaceContainerLow,
      appBar: AksharaAppBar(
        titleText: 'Report Card',
        subtitle: '${data.studentName} · ${data.classLabel}',
        onNotificationsTap: onNotificationsTap,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AksharaSpacing.s4),
        children: [
          AksharaSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Term summary', style: context.aksharaText.titleMedium),
                const SizedBox(height: AksharaSpacing.s2),
                Text(
                  'Average: ${data.averagePercent.toStringAsFixed(1)}%',
                  style: context.aksharaText.headlineSmall,
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
