import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/approvals/adapters/exam_results_approval_adapter.dart';
import '../../../core/approvals/approval_request_type.dart';
import '../../../core/config/exam_approval_config.dart';
import '../../../core/exams/exam_administration_store.dart';
import '../../../core/providers/repository_future.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/tenant/tenant_provider.dart';
import '../teacher_mutations_provider.dart';
import '../teacher_requests.dart';
import 'exam_models.dart';

final teacherExamSectionProvider = StateProvider<TeacherExamSection>(
  (ref) => TeacherExamSection.upcoming,
);

/// Demo teacher subject scope for marks-entry exam selector (M-A4).
const _teacherExamSubjectScope = 'Mathematics';

final teacherSelectedExamIdProvider = StateProvider<String?>((ref) => null);

final teacherMarksExamOptionsProvider = Provider<List<TeacherExamSessionOption>>(
  (ref) {
    ExamAdministrationStore.instance.ensureSeeded();
    return ExamAdministrationStore.instance
        .allExams()
        .where(
          (exam) =>
              exam.subject == _teacherExamSubjectScope &&
              (exam.phase == ExamLifecyclePhase.marksEntry ||
                  exam.phase == ExamLifecyclePhase.processed),
        )
        .map(
          (exam) => TeacherExamSessionOption(
            id: exam.id,
            title: exam.title,
            classLabel: exam.classLabel,
            maxMarks: exam.maxMarks,
          ),
        )
        .toList(growable: false);
  },
);

final teacherActiveExamIdProvider = Provider<String?>((ref) {
  final selected = ref.watch(teacherSelectedExamIdProvider);
  final options = ref.watch(teacherMarksExamOptionsProvider);
  if (selected != null && options.any((exam) => exam.id == selected)) {
    return selected;
  }
  if (options.isNotEmpty) return options.first.id;
  ExamAdministrationStore.instance.ensureSeeded();
  return ExamAdministrationStore.instance.activeMarksExamId;
});

final teacherExamMarksForActiveProvider = Provider<List<ExamMarkEntry>>((ref) {
  final examId = ref.watch(teacherActiveExamIdProvider);
  if (examId == null) return const [];
  ExamAdministrationStore.instance.ensureSeeded();
  final exam = ExamAdministrationStore.instance.examById(examId);
  if (exam == null) return const [];
  return [
    for (final mark in ExamAdministrationStore.instance.marksForExam(examId))
      ExamMarkEntry(
        id: mark.id,
        studentName: mark.studentName,
        rollNo: mark.rollNo,
        marksObtained: mark.marksObtained,
        maxMarks: exam.maxMarks,
      ),
  ];
});

final teacherExamsLoadingProvider = StateProvider<bool>((ref) => false);
final teacherExamsErrorProvider = StateProvider<bool>((ref) => false);
final teacherExamsEmptyProvider = StateProvider<bool>((ref) => false);

final teacherUpcomingExamsFutureProvider =
    FutureProvider<List<TeacherUpcomingExam>>((ref) async {
  return ref.read(teacherRepositoryProvider).getUpcomingExams(
        query: ref.watch(repositoryQueryProvider),
      );
});

final teacherExamMarksFutureProvider = FutureProvider<List<ExamMarkEntry>>((ref) async {
  return ref.read(teacherRepositoryProvider).getExamMarks(
        query: ref.watch(repositoryQueryProvider),
      );
});

final _teacherExamMarksProvider = StateProvider<List<ExamMarkEntry>?>((ref) => null);

List<ExamMarkEntry> _marks(Ref ref) {
  final override = ref.watch(_teacherExamMarksProvider);
  if (override != null) return override;
  final scoped = ref.watch(teacherExamMarksForActiveProvider);
  if (scoped.isNotEmpty) return scoped;
  return watchRepositoryFuture(
    ref,
    ref.watch(teacherExamMarksFutureProvider),
    manualLoading: ref.watch(teacherExamsLoadingProvider),
    manualError: ref.watch(teacherExamsErrorProvider),
    manualEmpty: ref.watch(teacherExamsEmptyProvider),
  ) ??
      ref.watch(teacherExamMarksFutureProvider).value ??
      const <ExamMarkEntry>[];
}

final teacherExamsProvider = Provider<TeacherExamsData>((ref) {
  if (ref.watch(teacherExamsEmptyProvider)) {
    return const TeacherExamsData(
      upcomingExams: [],
      markEntries: [],
      classAveragePercent: 0,
      unreadNotifications: 1,
    );
  }

  final marks = _marks(ref);
  final scored = marks.where((m) => m.marksObtained != null).toList();
  final avg = scored.isEmpty
      ? 0
      : (scored
              .map((m) => m.percent ?? 0)
              .fold<int>(0, (a, b) => a + b) /
          scored.length)
          .round();

  final upcoming = watchRepositoryFuture(
    ref,
    ref.watch(teacherUpcomingExamsFutureProvider),
    manualLoading: ref.watch(teacherExamsLoadingProvider),
    manualError: ref.watch(teacherExamsErrorProvider),
    manualEmpty: ref.watch(teacherExamsEmptyProvider),
  ) ??
      ref.watch(teacherUpcomingExamsFutureProvider).value ??
      const <TeacherUpcomingExam>[];

  return TeacherExamsData(
    upcomingExams: upcoming,
    markEntries: marks,
    classAveragePercent: avg,
    unreadNotifications: 1,
  );
});

Future<void> updateExamMark(WidgetRef ref, String entryId, int marks) async {
  final updated = await ref
      .read(updateTeacherExamMarkProvider.notifier)
      .execute(
        TeacherExamMarkUpdateRequest(
          markEntryId: entryId,
          marksObtained: marks,
        ),
      );
  if (updated == null) return;

  List<ExamMarkEntry> current = ref.read(teacherExamMarksForActiveProvider);
  final override = ref.read(_teacherExamMarksProvider);
  if (override != null) current = override;

  ref.read(_teacherExamMarksProvider.notifier).state = [
    for (final entry in current)
      entry.id == entryId ? entry.copyWith(marksObtained: marks) : entry,
  ];
  ref.invalidate(teacherExamMarksForActiveProvider);
}

void resetTeacherExamMarksOverride(WidgetRef ref) {
  ref.read(_teacherExamMarksProvider.notifier).state = null;
}

String? saveTeacherExamMarkFromInput(
  WidgetRef ref, {
  required ExamMarkEntry entry,
  required String raw,
}) {
  final error = validateTeacherExamMarkInput(raw, entry.maxMarks);
  if (error != null) return error;
  final marks = int.parse(raw.trim());
  unawaited(updateExamMark(ref, entry.id, marks));
  return null;
}

final teacherExamRejectionCommentProvider = Provider<String?>((ref) {
  final examId = ref.watch(teacherActiveExamIdProvider);
  if (examId == null) return null;
  return ExamAdministrationStore.instance.rejectionCommentFor(examId);
});

final teacherExamCoordinatorVerifiedProvider = Provider<bool>((ref) {
  final examId = ref.watch(teacherActiveExamIdProvider);
  if (examId == null) return false;
  ref.watch(teacherExamMarksFutureProvider);
  return ExamAdministrationStore.instance.isCoordinatorVerified(examId);
});

final teacherExamPhaseProvider = Provider<ExamLifecyclePhase?>((ref) {
  final examId = ref.watch(teacherActiveExamIdProvider);
  if (examId == null) return null;
  ref.watch(teacherExamMarksFutureProvider);
  return ExamAdministrationStore.instance.examById(examId)?.phase;
});

final teacherExamPendingApprovalProvider = FutureProvider<bool>((ref) async {
  if (!ref.watch(examApprovalRequiredProvider)) return false;
  final examId = ref.watch(teacherActiveExamIdProvider);
  if (examId == null) return false;

  final pending = await ref.read(approvalCenterServiceProvider).findPendingByEntity(
        query: ref.watch(repositoryQueryProvider),
        type: ApprovalRequestType.examResults,
        entityType: ExamResultsApprovalAdapter.entityType,
        entityId: examId,
      );
  return pending != null;
});

Future<TeacherExamPublishResult?> publishExamResults(
  WidgetRef ref,
  String examId,
) async {
  return ref.read(publishTeacherExamResultsProvider.notifier).execute(
        TeacherExamPublishRequest(examId: examId),
      );
}

Future<TeacherExamProcessResultsResult?> processExamResultsForVerification(
  WidgetRef ref,
  String examId,
) async {
  return ref.read(processTeacherExamResultsProvider.notifier).execute(
        TeacherExamProcessResultsRequest(examId: examId),
      );
}

Future<TeacherExamSubmitApprovalResult?> submitExamResultsForApproval(
  WidgetRef ref,
  String examId,
) async {
  return ref
      .read(submitTeacherExamResultsForApprovalProvider.notifier)
      .execute(TeacherExamSubmitApprovalRequest(examId: examId));
}
