import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/tenant/tenant_provider.dart';
import '../../../core/providers/repository_future.dart';

import '../../../core/repositories/repository_providers.dart';
import '../finance_async_state.dart';
import '../finance_models.dart';

final financeDashboardLoadingProvider = StateProvider<bool>((ref) => false);
final financeDashboardErrorProvider = StateProvider<bool>((ref) => false);
final financeDashboardEmptyProvider = StateProvider<bool>((ref) => false);
final financeDashboardFilterProvider = StateProvider<int>((ref) => 0);

final financeDashboardFutureProvider = FutureProvider<FinanceDashboardData>((ref) async {
return await ref.read(financeRepositoryProvider).getDashboard(query: ref.watch(repositoryQueryProvider));
});

final financeDashboardProvider = Provider<FinanceDashboardData?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(financeDashboardFutureProvider),
    manualLoading: ref.watch(financeDashboardLoadingProvider), manualError: ref.watch(financeDashboardErrorProvider), manualEmpty: ref.watch(financeDashboardEmptyProvider),
  );
});

final financeDashboardViewStateProvider =
    Provider<FinanceViewState<FinanceDashboardData>>((ref) {
  return resolveFinanceAsync(
    ref.watch(financeDashboardFutureProvider),
    forceLoading: ref.watch(financeDashboardLoadingProvider),
    forceError: ref.watch(financeDashboardErrorProvider),
    forceEmpty: ref.watch(financeDashboardEmptyProvider),
  );
});
