import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/communication/parent_communication_governance.dart';
import '../../../core/communication/parent_communication_models.dart';
import '../../../core/communication/subject_teacher_concern_store.dart';
import '../../../core/communication/teacher_student_risk_service.dart';
import '../../../core/repositories/mock/mock_canonical_student_registry.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/teaching/teacher_assignment_registry.dart';
import '../../../core/tenant/tenant_provider.dart';
import '../../auth/auth_models.dart';
import '../../auth/auth_provider.dart';
import '../teacher_requests.dart';

/// Active teaching assignment resolved from HR/SIS data for the logged-in teacher.
final teacherTeachingContextProvider = Provider<TeacherTeachingContext>((ref) {
  final auth = ref.watch(authProvider);
  if (auth.role != UserRole.teacher) {
    return TeacherAssignmentRegistry.resolveContext(
      teacherId: TeacherAssignmentRegistry.priyaSharmaId,
      teacherName: 'Priya Sharma',
    );
  }

  final displayName = auth.displayName ?? 'Priya Sharma';
  final teacherId = switch (displayName) {
    'Priya Sharma' || 'QA Teacher' => TeacherAssignmentRegistry.priyaSharmaId,
    'Mr. Patel' => TeacherAssignmentRegistry.mrPatelId,
    'Mrs. Rao' => TeacherAssignmentRegistry.mrsRaoId,
    _ => TeacherAssignmentRegistry.priyaSharmaId,
  };

  return TeacherAssignmentRegistry.resolveContext(
    teacherId: teacherId,
    teacherName: displayName,
  );
});

/// Override for QA: subject-teacher-only persona.
final teacherTeachingContextOverrideProvider =
    StateProvider<TeacherTeachingContext?>((ref) => null);

final resolvedTeacherTeachingContextProvider =
    Provider<TeacherTeachingContext>((ref) {
  return ref.watch(teacherTeachingContextOverrideProvider) ??
      ref.watch(teacherTeachingContextProvider);
});

final classStudentsNeedingAttentionProvider =
    Provider<List<StudentAttentionItem>>((ref) {
  final context = ref.watch(resolvedTeacherTeachingContextProvider);
  return TeacherStudentRiskService.attentionForClass(context);
});

final pendingSubjectConcernsProvider =
    FutureProvider<List<SubjectTeacherConcern>>((ref) async {
  final context = ref.watch(resolvedTeacherTeachingContextProvider);
  return ref.read(teacherRepositoryProvider).listPendingConcerns(
        query: ref.watch(repositoryQueryProvider),
        teachingContext: context,
      );
});

final teacherStudentRiskSnapshotProvider =
    Provider.family<TeacherStudentRiskSnapshot, String>((ref, sisStudentId) {
  return TeacherStudentRiskService.snapshotForStudent(sisStudentId);
});

Future<SubjectTeacherConcernFlagResult?> flagSubjectTeacherConcern(
  WidgetRef ref, {
  required String sisStudentId,
  required SubjectConcernCategory category,
  required String observation,
}) async {
  return ref.read(flagSubjectTeacherConcernProvider.notifier).execute(
        TeacherSubjectConcernFlagRequest(
          sisStudentId: sisStudentId,
          category: category,
          observation: observation,
        ),
      );
}

class FlagSubjectTeacherConcernNotifier
    extends AsyncNotifier<SubjectTeacherConcernFlagResult?> {
  @override
  FutureOr<SubjectTeacherConcernFlagResult?> build() => null;

  Future<SubjectTeacherConcernFlagResult?> execute(
    TeacherSubjectConcernFlagRequest request,
  ) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return ref.read(teacherRepositoryProvider).flagSubjectConcern(
            query: ref.read(repositoryQueryProvider),
            request: request,
            teachingContext: ref.read(resolvedTeacherTeachingContextProvider),
          );
    });
    ref.invalidate(pendingSubjectConcernsProvider);
    return state.valueOrNull;
  }
}

final flagSubjectTeacherConcernProvider = AsyncNotifierProvider<
    FlagSubjectTeacherConcernNotifier,
    SubjectTeacherConcernFlagResult?>(FlagSubjectTeacherConcernNotifier.new);

void seedDemoSubjectConcernIfNeeded() {
  final store = SubjectTeacherConcernStore.instance;
  if (store.allConcerns().isNotEmpty) return;
  store.flag(
    SubjectTeacherConcernFlagRequest(
      sisStudentId: MockCanonicalStudentRegistry.primaryMobileStudentId,
      category: SubjectConcernCategory.lowMarks,
      observation: 'Scored 38% in Mathematics unit test — needs revision support.',
      flaggedByTeacherId: TeacherAssignmentRegistry.mrPatelId,
      flaggedByTeacherName: 'Mr. Patel',
      subject: 'Science',
    ),
  );
}
