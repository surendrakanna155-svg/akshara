import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/repository_providers.dart';
import '../../../core/security/permissions.dart';
import '../../../core/security/rbac_service.dart';
import '../intelligence_provider.dart';
import 'student_success_models.dart';

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
  Future<void> build() async {}

  Future<int> compute() async {
    state = const AsyncLoading();
    try {
      final rows = await ref.read(intelligenceRepositoryProvider).computeStudentSuccess(
            query: ref.read(intelligenceQueryProvider),
          );
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
}
