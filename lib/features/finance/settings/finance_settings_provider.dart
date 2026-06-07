import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/tenant/tenant_provider.dart';
import '../../../core/providers/repository_future.dart';

import '../../../core/repositories/repository_providers.dart';
import '../finance_async_state.dart';
import '../finance_models.dart';

final financeSettingsLoadingProvider = StateProvider<bool>((ref) => false);
final financeSettingsErrorProvider = StateProvider<bool>((ref) => false);

final financeSettingsFutureProvider = FutureProvider<FinanceSettingsData>((ref) async {
return await ref.read(financeRepositoryProvider).getSettings(query: ref.watch(repositoryQueryProvider));
});

final financeSettingsProvider = Provider<FinanceSettingsData?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(financeSettingsFutureProvider),
    manualLoading: ref.watch(financeSettingsLoadingProvider), manualError: ref.watch(financeSettingsErrorProvider), manualEmpty: false,
  );
});

final financeSettingsViewStateProvider =
    Provider<FinanceViewState<FinanceSettingsData>>((ref) {
  return resolveFinanceAsync(
    ref.watch(financeSettingsFutureProvider),
    forceLoading: ref.watch(financeSettingsLoadingProvider),
    forceError: ref.watch(financeSettingsErrorProvider),
    isDataEmpty: (data) => data.sections.isEmpty,
  );
});
