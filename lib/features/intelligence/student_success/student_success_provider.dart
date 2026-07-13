import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/environment_provider.dart';
import '../../../core/repositories/repository_config.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/security/permissions.dart';
import '../../../core/security/rbac_service.dart';
import '../../../core/workflow/workflow_models.dart';
import '../intelligence_provider.dart';
import 'at_risk_student_intelligence.dart';
import 'student_success_models.dart';
import '../../../core/errors/mutation_in_progress.dart';

final studentSuccessCanViewProvider = Provider<bool>((ref) {
  final rbac = ref.watch(rbacServiceProvider);
  return rbac.hasPermission(Permission.viewStudentSuccessIntelligence) ||
      rbac.hasPermission(Permission.viewStudentRisk) ||
      rbac.hasPermission(Permission.viewAnalytics);
});

final studentSuccessDashboardProvider = FutureProvider<StudentSuccessDashboard>((ref) async {
  return ref.read(intelligenceRepositoryProvider).getStudentSuccessDashboard(
        query: ref.watch(intelligenceQueryProvider),
      );
});

final studentSuccessPredictionsProvider =
    FutureProvider<List<StudentSuccessSnapshot>>((ref) async {
  return ref.read(intelligenceRepositoryProvider).listStudentSuccessPredictions(
        query: ref.watch(intelligenceQueryProvider),
      );
});

final studentImprovementsProvider =
    FutureProvider<List<StudentImprovementItem>>((ref) async {
  return ref.read(intelligenceRepositoryProvider).listStudentImprovements(
        query: ref.watch(intelligenceQueryProvider),
      );
});

final interventionEffectivenessProvider =
    FutureProvider<List<InterventionEffectivenessItem>>((ref) async {
  return ref.read(intelligenceRepositoryProvider).listInterventionEffectiveness(
        query: ref.watch(intelligenceQueryProvider),
      );
});

final studentSuccessMutationsProvider =
    AsyncNotifierProvider<StudentSuccessMutationsNotifier, void>(
  StudentSuccessMutationsNotifier.new,
);

class StudentSuccessMutationsNotifier extends AsyncNotifier<void> {
  @override
  void build() {}

  Future<int> compute() async {
    if (state.isLoading) throw mutationInProgressFailure();
    state = const AsyncLoading();
    try {
      List<StudentSuccessSnapshot> previousRows;
      try {
        previousRows = await ref.read(studentSuccessPredictionsProvider.future);
      } catch (_) {
        previousRows = const <StudentSuccessSnapshot>[];
      }
      final rows = await ref.read(intelligenceRepositoryProvider).computeStudentSuccess(
            query: ref.read(intelligenceQueryProvider),
          );
      await _enqueueAtRiskTierTransitionWorkflows(previousRows, rows);
      ref.invalidate(studentSuccessDashboardProvider);
      ref.invalidate(studentSuccessPredictionsProvider);
      ref.invalidate(studentImprovementsProvider);
      ref.invalidate(interventionEffectivenessProvider);
      state = const AsyncData(null);
      return rows.length;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> _enqueueAtRiskTierTransitionWorkflows(
    List<StudentSuccessSnapshot> previousRows,
    List<StudentSuccessSnapshot> currentRows,
  ) async {
    // Honesty guard: the workflow-automation module has no live backend and its
    // API flag is OFF in the live release (see surface_backend_gate). In a real
    // (API-mode) build `workflowRepositoryProvider` is therefore the mock, whose
    // triggerWorkflow is a silent no-op — enqueuing here would falsely imply that
    // at-risk escalations were actioned. Skip it in that build; a local/mock
    // build (`enableApiMode` off) still exercises the mock as intended dev
    // behaviour. Wire this back on the day a real workflow backend + flag ship.
    final workflowBackendless =
        ref.read(enableApiModeProvider) && !ref.read(workflowApiEnabledProvider);
    if (workflowBackendless) return;
    final previousTierByStudent = <String, AtRiskTier>{
      for (final row in previousRows) row.studentId: classifyAtRiskTier(row),
    };
    for (final row in currentRows) {
      final nextTier = classifyAtRiskTier(row);
      final previousTier = previousTierByStudent[row.studentId];
      if (previousTier == nextTier) continue;
      if (nextTier.sortOrder < AtRiskTier.high.sortOrder) continue;
      await ref.read(workflowRepositoryProvider).triggerWorkflow(
            query: ref.read(intelligenceQueryProvider),
            triggerType: WorkflowTriggerType.atRiskTierChanged,
            payload: <String, Object?>{
              'studentId': row.studentId,
              'studentName': row.studentName,
              'className': row.className,
              'fromTier': previousTier?.name ?? 'none',
              'toTier': nextTier.name,
              'dropoutProbability': row.dropoutProbability,
            },
          );
    }
  }
}
