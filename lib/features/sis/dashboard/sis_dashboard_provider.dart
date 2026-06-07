import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_future.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/tenant/tenant_provider.dart';
import '../sis_async_state.dart';
import '../sis_models.dart';

final sisDashboardLoadingProvider = StateProvider<bool>((ref) => false);
final sisDashboardErrorProvider = StateProvider<bool>((ref) => false);
final sisDashboardEmptyProvider = StateProvider<bool>((ref) => false);
final sisDashboardFilterProvider = StateProvider<int>((ref) => 0);

final sisDashboardFutureProvider =
    FutureProvider<SisDashboardData>((ref) async {
  return ref
      .read(sisRepositoryProvider)
      .getDashboard(query: ref.watch(repositoryQueryProvider));
});

final sisDashboardProvider = Provider<SisDashboardData?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(sisDashboardFutureProvider),
    manualLoading: ref.watch(sisDashboardLoadingProvider),
    manualError: ref.watch(sisDashboardErrorProvider),
    manualEmpty: ref.watch(sisDashboardEmptyProvider),
  );
});

final sisDashboardViewStateProvider =
    Provider<SisViewState<SisDashboardData>>((ref) {
  return resolveSisAsync(
    ref.watch(sisDashboardFutureProvider),
    forceLoading: ref.watch(sisDashboardLoadingProvider),
    forceError: ref.watch(sisDashboardErrorProvider),
    forceEmpty: ref.watch(sisDashboardEmptyProvider),
  );
});
