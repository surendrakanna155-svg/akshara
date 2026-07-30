import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/communication/parent_communication_governance.dart';
import '../../../core/communication/parent_communication_models.dart';
import '../../../core/communication/teacher_student_risk_service.dart';
import '../../../core/repositories/repository_config.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/teaching/teacher_assignment_registry.dart';
import '../../../core/tenant/tenant_provider.dart';
import '../../auth/auth_models.dart';
import '../../auth/auth_provider.dart';
import '../../intelligence/intelligence_models.dart' as intel;
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

final pendingSubjectConcernsProvider =
    FutureProvider<List<SubjectTeacherConcern>>((ref) async {
  final context = ref.watch(resolvedTeacherTeachingContextProvider);
  return ref.read(teacherRepositoryProvider).listPendingConcerns(
        query: ref.watch(repositoryQueryProvider),
        teachingContext: context,
      );
});

/// Class-teacher 360 risk snapshot — **live only** (E2E-011).
///
/// The dossier is sourced from `/intelligence/risk/*` via
/// [intelligenceRepositoryProvider]. It returns `null` when the intelligence
/// module is off, when the call fails, or when the student is not in the live
/// feed — the screen then renders an honest "not available" state.
///
/// It used to fall back to `TeacherStudentRiskService.snapshotForStudent`, a
/// fixture composition that fabricated attendance (92), marks (75), homework
/// (80) and a fee statement (`₹4,200 due` for `acct_ravi`, else `No dues`).
/// The live merge replaced only the risk level/score/reasons, so every metric
/// row a class teacher read before a parent meeting was fabricated. That base
/// is gone; the four metrics stay `null` until each is wired to its real source
/// (`/attendance/*`, the exams feed, the homework store,
/// `/finance/student-accounts`).
final teacherStudentRiskSnapshotProvider =
    FutureProvider.family<TeacherStudentRiskSnapshot?, String>(
        (ref, sisStudentId) async {
  if (!isModuleApiEnabled(ref, intelligenceApiEnabledProvider)) return null;

  final repo = ref.read(intelligenceRepositoryProvider);
  final query = ref.read(repositoryQueryProvider);
  final risks = await repo.listStudentRisks(query: query);
  final live = _matchLiveRisk(risks, sisStudentId);
  if (live == null) return null;
  return _snapshotFromLive(sisStudentId, live);
});

/// Matches a live risk snapshot to the student id the UI carries.
intel.StudentRiskSnapshot? _matchLiveRisk(
  List<intel.StudentRiskSnapshot> risks,
  String sisStudentId,
) {
  for (final r in risks) {
    if (r.studentId == sisStudentId) return r;
  }
  return null;
}

/// Builds the dossier from the live verdict ONLY. Attendance / homework /
/// behaviour / fees are deliberately left null — the backend does not carry
/// them yet and the screen must say so rather than invent them.
TeacherStudentRiskSnapshot _snapshotFromLive(
  String sisStudentId,
  intel.StudentRiskSnapshot live,
) {
  final factors = live.reasons
      .map((r) => (r['label'] ?? r['code'] ?? '').toString())
      .where((s) => s.isNotEmpty && s.toLowerCase() != 'stable profile')
      .toList();
  return TeacherStudentRiskSnapshot(
    sisStudentId: sisStudentId,
    studentName: live.studentName?.trim().isNotEmpty == true
        ? live.studentName!.trim()
        : '',
    classLabel: live.className,
    rollNo: '',
    riskLevel: _riskLevelFromLive(live.riskLevel),
    riskFactors: factors,
    communicationHistoryCount: 0,
    pendingConcernCount: 0,
  );
}

StudentRiskLevel _riskLevelFromLive(intel.StudentRiskLevel level) {
  switch (level) {
    case intel.StudentRiskLevel.low:
      return StudentRiskLevel.low;
    case intel.StudentRiskLevel.medium:
      return StudentRiskLevel.medium;
    case intel.StudentRiskLevel.high:
    case intel.StudentRiskLevel.critical:
      return StudentRiskLevel.high;
  }
}

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
    if (state.isLoading) return state.valueOrNull;
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
