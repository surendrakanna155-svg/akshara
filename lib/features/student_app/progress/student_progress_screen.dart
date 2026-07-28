import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
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
    // Honest state — the exams snapshot is asynchronous, so loading and error
    // are first-class here exactly as on the sibling ST-05 exams screen. A
    // failed fetch must NEVER render as a populated-looking progress screen.
    final async = ref.watch(studentExamsFutureProvider);
    final data = ref.watch(studentExamsProvider);
    final isLoading = ref.watch(studentExamsLoadingProvider) || async.isLoading;
    final hasError = ref.watch(studentExamsErrorProvider) || async.hasError;

    // `weakSubjects.isEmpty` is TRUE both when every subject is strong and when
    // NOTHING has been measured. Only the former may be praised, so the
    // measured/unmeasured distinction is made explicitly.
    final hasMeasuredScores = data.subjectScores.isNotEmpty;
    final weakSubjects = data.subjectScores
        .where((score) => score.scorePercent < 70)
        .map((score) => score.subject)
        .toList(growable: false);

    return Scaffold(
      key: QaTestKeys.studentProgressScreen,
      backgroundColor: Colors.transparent,
      appBar: AksharaAppBar(
        titleText: 'My Progress',
        subtitle:
            async.hasValue ? '${data.studentName} · ${data.classLabel}' : null,
        showAi: true,
        onAiTap: onAiTap,
        onNotificationsTap: onNotificationsTap,
      ),
      // DS V2 P4 — premium persona canvas behind the progress content. The
      // per-subject scores stay as-is (no single headline %); presentation only.
      body: AksharaPremiumBackground(
        showMotif: false,
        child: isLoading
            ? const AksharaLoadingState(semanticLabel: 'Loading progress')
            : hasError
                ? AksharaErrorState(
                    message: 'Unable to load progress right now.',
                    onRetry: () {
                      ref.read(studentExamsErrorProvider.notifier).state =
                          false;
                      ref.invalidate(studentExamsFutureProvider);
                    },
                  )
                : ListView(
                    padding: const EdgeInsets.all(AksharaSpacing.s4),
                    children: [
                      if (hasMeasuredScores)
                        AksharaInsightCard(
                          message: weakSubjects.isEmpty
                              ? 'Strong performance across subjects — keep your '
                                  'revision streak.'
                              : 'Focus revision on ${weakSubjects.join(', ')} '
                                  'this week.',
                          actionLabel: 'Ask AI tutor',
                          icon: Icons.auto_stories_outlined,
                          semanticLabelPrefix: 'AI study guidance',
                          onAction: onAiTap,
                        )
                      else
                        // Nothing measured yet → say so. No praise, no blame.
                        const AksharaSectionEmpty(
                          message: 'No subject scores published yet — study '
                              'guidance appears once results are published.',
                          icon: Icons.auto_stories_outlined,
                        ),
                      const SizedBox(height: AksharaSpacing.s4),
                      const AksharaSectionHeader(title: 'Subject progress'),
                      const SizedBox(height: AksharaSpacing.s3),
                      if (!hasMeasuredScores)
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
                    ],
                  ),
      ),
    );
  }
}
