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

/// Class-teacher 360 risk snapshot.
///
/// When the live Intelligence backend is enabled (INTELLIGENCE_API_ENABLED) the
/// authoritative risk verdict (level + reasons + score) is sourced from
/// `/intelligence/risk/*` via [intelligenceRepositoryProvider]; the locally
/// computed snapshot supplies the per-metric display rows. On any live failure
/// (or when the module is off) it falls back to the deterministic mock snapshot.
final teacherStudentRiskSnapshotProvider =
    FutureProvider.family<TeacherStudentRiskSnapshot, String>(
        (ref, sisStudentId) async {
  final base = TeacherStudentRiskService.snapshotForStudent(sisStudentId);

  if (!isModuleApiEnabled(ref, intelligenceApiEnabledProvider)) {
    return base;
  }

  try {
    final repo = ref.read(intelligenceRepositoryProvider);
    final query = ref.read(repositoryQueryProvider);
    final risks = await repo.listStudentRisks(query: query);
    final live = _matchLiveRisk(risks, base);
    if (live == null) return base;
    return _mergeLiveRisk(base, live);
  } catch (_) {
    // Live unavailable (no backend / network / key) — graceful mock fallback.
    return base;
  }
});

/// Matches a live risk snapshot to the resolved student. The live backend keys
/// on the DB student UUID while the UI carries the SIS id, so we match on the
/// student name as the stable cross-source identifier, falling back to the id.
intel.StudentRiskSnapshot? _matchLiveRisk(
  List<intel.StudentRiskSnapshot> risks,
  TeacherStudentRiskSnapshot base,
) {
  for (final r in risks) {
    if (r.studentId == base.sisStudentId) return r;
  }
  for (final r in risks) {
    if (r.studentName != null &&
        r.studentName!.trim().toLowerCase() ==
            base.studentName.trim().toLowerCase()) {
      return r;
    }
  }
  return null;
}

/// Overlays the authoritative live risk verdict on the locally-computed snapshot.
TeacherStudentRiskSnapshot _mergeLiveRisk(
  TeacherStudentRiskSnapshot base,
  intel.StudentRiskSnapshot live,
) {
  final factors = live.reasons
      .map((r) => (r['label'] ?? r['code'] ?? '').toString())
      .where((s) => s.isNotEmpty && s.toLowerCase() != 'stable profile')
      .toList();
  return TeacherStudentRiskSnapshot(
    sisStudentId: base.sisStudentId,
    studentName: live.studentName?.trim().isNotEmpty == true
        ? live.studentName!.trim()
        : base.studentName,
    classLabel: live.className.isNotEmpty ? live.className : base.classLabel,
    rollNo: base.rollNo,
    attendancePercent: base.attendancePercent,
    attendanceTrend: base.attendanceTrend,
    subjectPerformance: base.subjectPerformance,
    homeworkCompletionPercent: base.homeworkCompletionPercent,
    behaviorIncidentCount: base.behaviorIncidentCount,
    feePendingLabel: base.feePendingLabel,
    riskLevel: _riskLevelFromLive(live.riskLevel),
    riskFactors: factors.isNotEmpty ? factors : base.riskFactors,
    communicationHistoryCount: base.communicationHistoryCount,
    pendingConcernCount: base.pendingConcernCount,
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
