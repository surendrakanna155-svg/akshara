import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/tenant/tenant_provider.dart';
import '../../../core/providers/repository_future.dart';

import '../../../core/repositories/repository_providers.dart';
import '../admissions_async_state.dart';
import '../admissions_models.dart';

final admissionsSettingsLoadingProvider = StateProvider<bool>((ref) => false);
final admissionsSettingsErrorProvider = StateProvider<bool>((ref) => false);

final admissionsSettingsFutureProvider = FutureProvider<AdmissionsSettingsData>((ref) async {
return await ref.read(admissionsRepositoryProvider).getSettings(query: ref.watch(repositoryQueryProvider));
});

final admissionsSettingsProvider = Provider<AdmissionsSettingsData?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(admissionsSettingsFutureProvider),
    manualLoading: ref.watch(admissionsSettingsLoadingProvider), manualError: ref.watch(admissionsSettingsErrorProvider), manualEmpty: false,
  );
});

final admissionsSettingsViewStateProvider =
    Provider<AdmissionsViewState<AdmissionsSettingsData>>((ref) {
  return resolveAdmissionsAsync(
    ref.watch(admissionsSettingsFutureProvider),
    forceLoading: ref.watch(admissionsSettingsLoadingProvider),
    forceError: ref.watch(admissionsSettingsErrorProvider),
  );
});
