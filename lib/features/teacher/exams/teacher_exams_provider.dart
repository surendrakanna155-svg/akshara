import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/approvals/adapters/exam_results_approval_adapter.dart';
import '../../../core/approvals/approval_request_type.dart';
import '../../../core/config/exam_approval_config.dart';
import '../../../core/exams/exam_administration_store.dart';
import '../../../core/providers/repository_future.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/tenant/tenant_provider.dart';
import '../../academics/exam_admin/exam_administration_provider.dart';
import '../communication/teacher_teaching_context_provider.dart';
import '../teacher_mutations_provider.dart';
import '../teacher_requests.dart';
import 'exam_models.dart';

final teacherExamSectionProvider = StateProvider<TeacherExamSection>(
  (ref) => TeacherExamSection.upcoming,
);

final teacherSelectedExamIdProvider = StateProvider<String?>((ref) => null);

final teacherExamRefreshTickProvider = StateProvider<int>((ref) => 0);

final teacherMarksExamOptionsProvider =
    FutureProvider<List<TeacherExamSessionOption>>((ref) async {
  ref.watch(teacherExamRefreshTickProvider);
  ref.watch(examAdminRefreshTickProvider);
  return ref.read(teacherRepositoryProvider).getMarksEntryExams(
        query: ref.watch(repositoryQueryProvider),
        teachingContext: ref.watch(resolvedTeacherTeachingContextProvider),
      );
});

final teacherActiveExamIdProvider = Provider<String?>((ref) {
  final selected = ref.watch(teacherSelectedExamIdProvider);
  final optionsAsync = ref.watch(teacherMarksExamOptionsProvider);
  final options = optionsAsync.valueOrNull ?? const [];
  if (selected != null && options.any((exam) => exam.id == selected)) {
    return selected;
  }
  if (options.isNotEmpty) return options.first.id;
  return null;
});

final teacherActiveExamProvider = Provider<TeacherExamSessionOption?>((ref) {
  final examId = ref.watch(teacherActiveExamIdProvider);
  if (examId == null) return null;
  final options = ref.watch(teacherMarksExamOptionsProvider).valueOrNull ?? const [];
  for (final opt in options) {
    if (opt.id == examId) return opt;
  }
  return null;
});

final teacherExamMarksForActiveProvider =
    FutureProvider<List<ExamMarkEntry>>((ref) async {
  final examId = ref.watch(teacherActiveExamIdProvider);
  if (examId == null) return const [];
  ref.watch(teacherExamRefreshTickProvider);
  ref.watch(examAdminRefreshTickProvider);
  return ref.read(teacherRepositoryProvider).getExamMarks(
        query: ref.watch(repositoryQueryProvider),
        examId: examId,
      );
});

final teacherExamsLoadingProvider = StateProvider<bool>((ref) => false);
final teacherExamsErrorProvider = StateProvider<bool>((ref) => false);
final teacherExamsEmptyProvider = StateProvider<bool>((ref) => false);

final teacherUpcomingExamsFutureProvider =
    FutureProvider<List<TeacherUpcomingExam>>((ref) async {
  ref.watch(teacherExamRefreshTickProvider);
  ref.watch(examAdminRefreshTickProvider);
  return ref.read(teacherRepositoryProvider).getUpcomingExams(
        query: ref.watch(repositoryQueryProvider),
        teachingContext: ref.watch(resolvedTeacherTeachingContextProvider),
      );
});

final teacherExamMarksFutureProvider =
    FutureProvider<List<ExamMarkEntry>>((ref) async {
  ref.watch(teacherExamRefreshTickProvider);
  ref.watch(examAdminRefreshTickProvider);
  return ref.read(teacherRepositoryProvider).getExamMarks(
        query: ref.watch(repositoryQueryProvider),
      );
});

final _teacherExamMarksProvider =
    StateProvider<List<ExamMarkEntry>?>((ref) => null);

List<ExamMarkEntry> _marks(Ref ref) {
  final override = ref.watch(_teacherExamMarksProvider);
  if (override != null) return override;
  final scoped = ref.watch(teacherExamMarksForActiveProvider);
  if (scoped.valueOrNull != null && scoped.valueOrNull!.isNotEmpty) {
    return scoped.valueOrNull!;
  }
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

  final override = ref.read(_teacherExamMarksProvider);
  List<ExamMarkEntry> current =
      override ?? ref.read(teacherExamMarksForActiveProvider).valueOrNull ?? const [];

  ref.read(_teacherExamMarksProvider.notifier).state = [
    for (final entry in current)
      entry.id == entryId ? entry.copyWith(marksObtained: marks) : entry,
  ];
  _bumpTeacherExamRefresh(ref);
}

void _bumpTeacherExamRefresh(WidgetRef ref) {
  ref.read(teacherExamRefreshTickProvider.notifier).state++;
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
  final exam = ref.watch(teacherActiveExamProvider);
  return exam?.rejectionComment;
});

final teacherExamCoordinatorVerifiedProvider = Provider<bool>((ref) {
  final exam = ref.watch(teacherActiveExamProvider);
  return exam?.coordinatorVerified ?? false;
});

/// Whether the current teacher is the class teacher of the active exam's class —
/// the primary author of exam-session remarks.
final teacherIsClassTeacherForActiveExamProvider = Provider<bool>((ref) {
  final exam = ref.watch(teacherActiveExamProvider);
  if (exam == null) return false;
  final ctx = ref.watch(resolvedTeacherTeachingContextProvider);
  return ctx.isClassTeacher && ctx.classTeacherClassLabel == exam.classLabel;
});

String? teacherExamRemarkText(
  WidgetRef ref,
  String examId,
  String sisStudentId,
) {
  ref.watch(teacherExamRefreshTickProvider);
  return ExamAdministrationStore.instance.remarkFor(examId, sisStudentId)?.text;
}

/// Class teacher creates/edits a student's remark for an exam session.
Future<void> saveTeacherExamRemark(
  WidgetRef ref, {
  required String examId,
  required String sisStudentId,
  required String text,
}) async {
  final ctx = ref.read(resolvedTeacherTeachingContextProvider);
  ExamAdministrationStore.instance.upsertRemark(
    examId: examId,
    sisStudentId: sisStudentId,
    text: text.trim(),
    authorId: ctx.teacherId,
    authorName: ctx.teacherName,
  );
  ref.read(teacherExamRefreshTickProvider.notifier).state++;
}

final teacherExamPhaseProvider = Provider<ExamLifecyclePhase?>((ref) {
  final exam = ref.watch(teacherActiveExamProvider);
  if (exam == null) return null;
  final label = exam.phaseLabel;
  if (label.isEmpty) return null;
  return ExamLifecyclePhase.values.where((p) => p.name == label).firstOrNull;
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
  final result = await ref.read(publishTeacherExamResultsProvider.notifier).execute(
        TeacherExamPublishRequest(examId: examId),
      );
  _bumpTeacherExamRefresh(ref);
  return result;
}

Future<TeacherExamProcessResultsResult?> processExamResultsForVerification(
  WidgetRef ref,
  String examId,
) async {
  final result = await ref.read(processTeacherExamResultsProvider.notifier).execute(
        TeacherExamProcessResultsRequest(examId: examId),
      );
  _bumpTeacherExamRefresh(ref);
  return result;
}

Future<TeacherExamSubmitApprovalResult?> submitExamResultsForApproval(
  WidgetRef ref,
  String examId,
) async {
  final result = await ref
      .read(submitTeacherExamResultsForApprovalProvider.notifier)
      .execute(TeacherExamSubmitApprovalRequest(examId: examId));
  _bumpTeacherExamRefresh(ref);
  return result;
}
