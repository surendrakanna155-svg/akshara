import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/exams/exam_administration_store.dart';
import '../../../../core/security/permissions.dart';
import '../../../../core/testing/qa_test_keys.dart';
import '../../../../shared/widgets/akshara_manage_action.dart';
import '../../../../shared/widgets/akshara_view_action.dart';
import '../../../../theme/spacing.dart';
import '../exam_admin_navigation.dart';
import '../exam_administration_provider.dart';

class ExamLifecycleActions extends ConsumerWidget {
  const ExamLifecycleActions({super.key, required this.exam});

  final ExamSession exam;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: AksharaSpacing.s2,
      runSpacing: AksharaSpacing.s2,
      children: [
        if (exam.phase == ExamLifecyclePhase.draft)
          AksharaManageAction(
            permission: Permission.manageExams,
            auditRoute: '/school/exam-administration',
            child: OutlinedButton(
              key: QaTestKeys.examAdminScheduleButton(exam.id),
              onPressed: () => _schedule(context, ref),
              child: const Text('Schedule'),
            ),
          ),
        if (exam.phase == ExamLifecyclePhase.scheduled)
          AksharaManageAction(
            permission: Permission.manageExams,
            auditRoute: '/school/exam-administration',
            child: FilledButton(
              key: QaTestKeys.examAdminOpenMarksButton(exam.id),
              onPressed: () => _openMarks(context, ref),
              child: const Text('Open marks entry'),
            ),
          ),
        if (exam.phase == ExamLifecyclePhase.marksEntry ||
            exam.phase == ExamLifecyclePhase.processed)
          AksharaViewAction(
            permission: Permission.manageExamMarks,
            child: OutlinedButton(
              key: QaTestKeys.examAdminEnterMarksButton(exam.id),
              onPressed: () => openExamMarksEntry(context, exam.id),
              child: const Text('Enter marks'),
            ),
          ),
      ],
    );
  }

  Future<void> _schedule(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(examAdminMutationProvider.notifier).scheduleExam(exam.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${exam.title} scheduled')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }

  Future<void> _openMarks(BuildContext context, WidgetRef ref) async {
    try {
      await ref
          .read(examAdminMutationProvider.notifier)
          .openMarksEntry(exam.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Marks entry opened for ${exam.title}')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }
}
