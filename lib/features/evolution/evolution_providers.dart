import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/repositories/repository_providers.dart';
import '../../core/repositories/repository_query.dart';
import '../../core/tenant/tenant_provider.dart';
import 'evolution_models.dart';

final evolutionQueryProvider = Provider<RepositoryQuery>(
  (ref) => ref.watch(repositoryQueryProvider),
);

final teacherClassFilterProvider = StateProvider<String?>((ref) => null);

final growthFunnelProvider = FutureProvider<GrowthFunnel>((ref) async {
  return ref.read(evolutionRepositoryProvider).getGrowthFunnel(
        query: ref.watch(evolutionQueryProvider),
      );
});

final parentLanguagePreferenceProvider = FutureProvider.family<String, String?>(
  (ref, studentId) async {
    return await ref.read(evolutionRepositoryProvider).getParentLanguagePreference(
              query: ref.watch(evolutionQueryProvider),
              studentId: studentId,
            ) ??
        'english';
  },
);

final operationsActionsProvider = FutureProvider<List<OperationsActionItem>>((ref) async {
  return ref.read(evolutionRepositoryProvider).getOperationsActions(
        query: ref.watch(evolutionQueryProvider),
      );
});

final setupWizardProvider = FutureProvider<SetupWizardSession>((ref) async {
  return ref.read(evolutionRepositoryProvider).createSetupWizard(
        query: ref.watch(evolutionQueryProvider),
        inputs: const {'schoolName': 'NIKSHA Demo School', 'studentCount': 200, 'teacherCount': 12},
      );
});

final teacherAssistantInsightsProvider = FutureProvider<TeacherAssistantInsights>((ref) async {
  final className = ref.watch(teacherClassFilterProvider);
  return ref.read(evolutionRepositoryProvider).getTeacherAssistantInsights(
        query: ref.watch(evolutionQueryProvider),
        className: className,
      );
});

final teacherInterventionsProvider = FutureProvider<List<TeacherIntervention>>((ref) async {
  return ref.read(evolutionRepositoryProvider).listInterventions(
        query: ref.watch(evolutionQueryProvider),
      );
});

final parentInsightsProvider = FutureProvider.family<List<ParentInsightSnapshot>, String>(
  (ref, studentId) async {
    return ref.read(evolutionRepositoryProvider).listParentInsights(
          query: ref.watch(evolutionQueryProvider),
          studentId: studentId,
        );
  },
);

final principalCommandProvider = FutureProvider<PrincipalCommandCenter>((ref) async {
  return ref.read(evolutionRepositoryProvider).getPrincipalCommandCenter(
        query: ref.watch(evolutionQueryProvider),
      );
});

final growthDashboardProvider = FutureProvider<GrowthDashboard>((ref) async {
  return ref.read(evolutionRepositoryProvider).getGrowthDashboard(
        query: ref.watch(evolutionQueryProvider),
      );
});

final growthCampaignsProvider = FutureProvider<List<GrowthCampaign>>((ref) async {
  return ref.read(evolutionRepositoryProvider).listGrowthCampaigns(
        query: ref.watch(evolutionQueryProvider),
      );
});

final growthInquiriesProvider = FutureProvider<List<GrowthInquiry>>((ref) async {
  return ref.read(evolutionRepositoryProvider).listGrowthInquiries(
        query: ref.watch(evolutionQueryProvider),
      );
});
