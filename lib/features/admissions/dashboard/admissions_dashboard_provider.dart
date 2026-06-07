import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/tenant/tenant_provider.dart';
import '../../../core/providers/repository_future.dart';
import '../../../core/repositories/repository_providers.dart';
import '../admissions_async_state.dart';
import '../admissions_models.dart';

final admissionsDashboardLoadingProvider = StateProvider<bool>((ref) => false);
final admissionsDashboardErrorProvider = StateProvider<bool>((ref) => false);
final admissionsDashboardEmptyProvider = StateProvider<bool>((ref) => false);

final admissionsDashboardFilterProvider = StateProvider<int>((ref) => 0);

final admissionsDashboardFutureProvider = FutureProvider<AdmissionsDashboardData>((ref) async {
return await ref.read(admissionsRepositoryProvider).getDashboard(query: ref.watch(repositoryQueryProvider));
});

final admissionsDashboardProvider = Provider<AdmissionsDashboardData?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(admissionsDashboardFutureProvider),
    manualLoading: ref.watch(admissionsDashboardLoadingProvider), manualError: ref.watch(admissionsDashboardErrorProvider), manualEmpty: ref.watch(admissionsDashboardEmptyProvider),
  );
});

final admissionsDashboardViewStateProvider =
    Provider<AdmissionsViewState<AdmissionsDashboardData>>((ref) {
  return resolveAdmissionsAsync(
    ref.watch(admissionsDashboardFutureProvider),
    forceLoading: ref.watch(admissionsDashboardLoadingProvider),
    forceError: ref.watch(admissionsDashboardErrorProvider),
    forceEmpty: ref.watch(admissionsDashboardEmptyProvider),
  );
});
