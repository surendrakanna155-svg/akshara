import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../exams/student_exams_provider.dart';
import '../exams/widgets/subject_score_row.dart';

/// ST-07 — Academic progress view with AI study guidance.
class StudentProgressScreen extends ConsumerWidget {
  const StudentProgressScreen({
    super.key,
    this.onNotificationsTap,
    this.onAiTap,
  });

  final VoidCallback? onNotificationsTap;
  final VoidCallback? onAiTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(studentExamsProvider);
    final weakSubjects = data.subjectScores
        .where((score) => score.scorePercent < 70)
        .map((score) => score.subject)
        .toList(growable: false);

    return Scaffold(
      key: QaTestKeys.studentProgressScreen,
      backgroundColor: context.colors.surfaceContainerLow,
      appBar: AksharaAppBar(
        titleText: 'My Progress',
        subtitle: '${data.studentName} · ${data.classLabel}',
        showAi: true,
        onAiTap: onAiTap,
        onNotificationsTap: onNotificationsTap,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AksharaSpacing.s4),
        children: [
          AksharaInsightCard(
            message: weakSubjects.isEmpty
                ? 'Strong performance across subjects — keep your revision streak.'
                : 'Focus revision on ${weakSubjects.join(', ')} this week.',
            actionLabel: 'Ask AI tutor',
            icon: Icons.auto_stories_outlined,
            semanticLabelPrefix: 'AI study guidance',
            onAction: onAiTap,
          ),
          const SizedBox(height: AksharaSpacing.s4),
          const AksharaSectionHeader(title: 'Subject progress'),
          const SizedBox(height: AksharaSpacing.s3),
          for (final score in data.subjectScores)
            Padding(
              padding: const EdgeInsets.only(bottom: AksharaSpacing.s2),
              child: SubjectScoreRow(score: score),
            ),
        ],
      ),
    );
  }
}
