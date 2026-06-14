import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_future.dart';
import '../../../core/repositories/paginated_result.dart';
import '../../../core/repositories/repository_query.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/tenant/tenant_provider.dart';
import '../finance_async_state.dart';
import '../finance_models.dart';

final financeInvoicesLoadingProvider = StateProvider<bool>((ref) => false);
final financeInvoicesErrorProvider = StateProvider<bool>((ref) => false);
final financeInvoicesEmptyProvider = StateProvider<bool>((ref) => false);

final financeInvoicesQueryProvider = Provider<RepositoryQuery>((ref) {
  return ref.watch(repositoryQueryProvider).withPage(1, pageSize: 200);
});

final financeInvoicesFutureProvider =
    FutureProvider<PaginatedResult<FinanceInvoice>>((ref) async {
  return ref.read(financeRepositoryProvider).getInvoices(
        query: ref.watch(financeInvoicesQueryProvider),
      );
});

final financeInvoicesProvider = Provider<List<FinanceInvoice>>((ref) {
  return watchRepositoryFuture(
        ref,
        ref.watch(financeInvoicesFutureProvider),
        manualLoading: ref.watch(financeInvoicesLoadingProvider),
        manualError: ref.watch(financeInvoicesErrorProvider),
        manualEmpty: ref.watch(financeInvoicesEmptyProvider),
      )?.items ??
      const [];
});

final financeInvoicesViewStateProvider =
    Provider<FinanceViewState<PaginatedResult<FinanceInvoice>>>((ref) {
  return resolveFinanceAsync(
    ref.watch(financeInvoicesFutureProvider),
    forceLoading: ref.watch(financeInvoicesLoadingProvider),
    forceError: ref.watch(financeInvoicesErrorProvider),
    forceEmpty: ref.watch(financeInvoicesEmptyProvider),
    isDataEmpty: (result) => result.items.isEmpty,
  );
});
