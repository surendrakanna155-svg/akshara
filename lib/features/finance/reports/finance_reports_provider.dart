import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/tenant/tenant_provider.dart';
import '../../../core/providers/repository_future.dart';

import '../../../core/repositories/repository_providers.dart';
import '../finance_async_state.dart';
import '../finance_models.dart';

final financeReportsLoadingProvider = StateProvider<bool>((ref) => false);
final financeReportsErrorProvider = StateProvider<bool>((ref) => false);
final financeReportsEmptyProvider = StateProvider<bool>((ref) => false);
final financeSelectedReportIdProvider = StateProvider<String>((ref) => 'rpt_collection');

final financeReportsFutureProvider = FutureProvider<FinanceReportsData>((ref) async {
return await ref.read(financeRepositoryProvider).getReportsData(query: ref.watch(repositoryQueryProvider));
});

final financeReportsProvider = Provider<FinanceReportsData?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(financeReportsFutureProvider),
    manualLoading: ref.watch(financeReportsLoadingProvider), manualError: ref.watch(financeReportsErrorProvider), manualEmpty: ref.watch(financeReportsEmptyProvider),
  );
});

final financeReportsViewStateProvider =
    Provider<FinanceViewState<FinanceReportsData>>((ref) {
  return resolveFinanceAsync(
    ref.watch(financeReportsFutureProvider),
    forceLoading: ref.watch(financeReportsLoadingProvider),
    forceError: ref.watch(financeReportsErrorProvider),
    forceEmpty: ref.watch(financeReportsEmptyProvider),
    isDataEmpty: (data) => data.catalog.isEmpty,
  );
});
