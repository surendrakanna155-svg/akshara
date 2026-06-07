import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/tenant/tenant_provider.dart';
import '../../../core/providers/repository_future.dart';

import '../../../core/repositories/repository_providers.dart';
import '../finance_async_state.dart';
import '../finance_models.dart';

final financeDiscountsLoadingProvider = StateProvider<bool>((ref) => false);
final financeDiscountsErrorProvider = StateProvider<bool>((ref) => false);
final financeDiscountsEmptyProvider = StateProvider<bool>((ref) => false);
final financeDiscountsTabProvider = StateProvider<int>((ref) => 0);

final financeDiscountsFutureProvider = FutureProvider<DiscountsDashboardData>((ref) async {
return await ref.read(financeRepositoryProvider).getDiscountsDashboard(query: ref.watch(repositoryQueryProvider));
});

final financeDiscountsProvider = Provider<DiscountsDashboardData?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(financeDiscountsFutureProvider),
    manualLoading: ref.watch(financeDiscountsLoadingProvider), manualError: ref.watch(financeDiscountsErrorProvider), manualEmpty: ref.watch(financeDiscountsEmptyProvider),
  );
});

final financeDiscountsViewStateProvider =
    Provider<FinanceViewState<DiscountsDashboardData>>((ref) {
  return resolveFinanceAsync(
    ref.watch(financeDiscountsFutureProvider),
    forceLoading: ref.watch(financeDiscountsLoadingProvider),
    forceError: ref.watch(financeDiscountsErrorProvider),
    forceEmpty: ref.watch(financeDiscountsEmptyProvider),
  );
});
