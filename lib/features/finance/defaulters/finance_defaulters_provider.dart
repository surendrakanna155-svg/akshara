import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/tenant/tenant_provider.dart';
import '../../../core/providers/repository_future.dart';

import '../../../core/repositories/repository_providers.dart';
import '../finance_async_state.dart';
import '../finance_models.dart';

final financeDefaultersLoadingProvider = StateProvider<bool>((ref) => false);
final financeDefaultersErrorProvider = StateProvider<bool>((ref) => false);
final financeDefaultersEmptyProvider = StateProvider<bool>((ref) => false);
final financeDefaultersFilterProvider = StateProvider<int>((ref) => 0);
final financeSelectedDefaulterIdProvider = StateProvider<String?>((ref) => null);

final financeDefaultersFutureProvider = FutureProvider<DefaultersDashboardData>((ref) async {
return await ref.read(financeRepositoryProvider).getDefaultersDashboard(query: ref.watch(repositoryQueryProvider));
});

final financeDefaultersProvider = Provider<DefaultersDashboardData?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(financeDefaultersFutureProvider),
    manualLoading: ref.watch(financeDefaultersLoadingProvider), manualError: ref.watch(financeDefaultersErrorProvider), manualEmpty: ref.watch(financeDefaultersEmptyProvider),
  );
});

final financeDefaultersViewStateProvider =
    Provider<FinanceViewState<DefaultersDashboardData>>((ref) {
  return resolveFinanceAsync(
    ref.watch(financeDefaultersFutureProvider),
    forceLoading: ref.watch(financeDefaultersLoadingProvider),
    forceError: ref.watch(financeDefaultersErrorProvider),
    forceEmpty: ref.watch(financeDefaultersEmptyProvider),
    isDataEmpty: (data) => data.defaulters.isEmpty,
  );
});

final financeFilteredDefaultersProvider = Provider<List<DefaulterRecord>>((ref) {
  final data = ref.watch(financeDefaultersProvider);
  if (data == null) return const [];
  final filterIndex = ref.watch(financeDefaultersFilterProvider);
  return switch (filterIndex) {
    1 => data.defaulters
        .where((d) => d.bucket == DefaulterAgingBucket.days1to30)
        .toList(),
    2 => data.defaulters
        .where((d) => d.bucket == DefaulterAgingBucket.days31to60)
        .toList(),
    3 => data.defaulters
        .where((d) => d.bucket == DefaulterAgingBucket.over90)
        .toList(),
    _ => data.defaulters,
  };
});

final financeSelectedDefaulterProvider = Provider<DefaulterRecord?>((ref) {
  final defaulters = ref.watch(financeFilteredDefaultersProvider);
  final selectedId = ref.watch(financeSelectedDefaulterIdProvider);
  if (selectedId != null) {
    for (final record in defaulters) {
      if (record.id == selectedId) return record;
    }
  }
  return defaulters.isEmpty ? null : defaulters.first;
});
