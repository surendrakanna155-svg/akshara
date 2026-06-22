import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/repository_providers.dart';
import '../../../core/tenant/tenant_provider.dart';
import 'multi_school_models.dart';

final multiSchoolQueryProvider = Provider((ref) {
  return ref.watch(repositoryQueryProvider);
});

final multiSchoolPortfolioDashboardProvider =
    FutureProvider<SchoolPortfolioDashboard>((ref) async {
  return ref
      .read(multiSchoolOperationsRepositoryProvider)
      .getPortfolioDashboard(
        query: ref.watch(multiSchoolQueryProvider),
      );
});

final multiSchoolLifecycleFilterProvider =
    StateProvider<SchoolLifecycleStatus?>((ref) => null);

final multiSchoolSchoolsProvider = FutureProvider<List<SchoolLifecycleRecord>>((
  ref,
) async {
  return ref.read(multiSchoolOperationsRepositoryProvider).listSchools(
        query: ref.watch(multiSchoolQueryProvider),
        status: ref.watch(multiSchoolLifecycleFilterProvider),
      );
});

final multiSchoolHealthProvider =
    FutureProvider.family<SchoolHealthScore, String>((ref, schoolId) async {
  return ref.read(multiSchoolOperationsRepositoryProvider).getSchoolHealth(
        query: ref.watch(multiSchoolQueryProvider),
        schoolId: schoolId,
      );
});

final multiSchoolAlertsProvider = FutureProvider<List<PortfolioAlert>>((
  ref,
) async {
  return ref.read(multiSchoolOperationsRepositoryProvider).listAlerts(
        query: ref.watch(multiSchoolQueryProvider),
      );
});

final multiSchoolPendingActionsProvider =
    FutureProvider<List<PortfolioAction>>((
  ref,
) async {
  return ref.read(multiSchoolOperationsRepositoryProvider).listPendingActions(
        query: ref.watch(multiSchoolQueryProvider),
      );
});
