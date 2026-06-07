import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/tenant/tenant_provider.dart';
import '../../../core/providers/repository_future.dart';

import '../../../core/repositories/repository_providers.dart';
import '../admissions_async_state.dart';
import '../admissions_models.dart';

final admissionsLeadsLoadingProvider = StateProvider<bool>((ref) => false);
final admissionsLeadsErrorProvider = StateProvider<bool>((ref) => false);
final admissionsLeadsEmptyProvider = StateProvider<bool>((ref) => false);

final admissionsLeadsFilterProvider = StateProvider<int>((ref) => 0);

final admissionsLeadsFutureProvider = FutureProvider<List<AdmissionsLead>>((ref) async {
return ref.read(admissionsRepositoryProvider).getLeads(query: ref.watch(repositoryQueryProvider));
});

final admissionsLeadsProvider = Provider<List<AdmissionsLead>>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(admissionsLeadsFutureProvider),
    manualLoading: ref.watch(admissionsLeadsLoadingProvider), manualError: ref.watch(admissionsLeadsErrorProvider), manualEmpty: ref.watch(admissionsLeadsEmptyProvider),
  ) ?? const [];
});

final admissionsLeadsViewStateProvider =
    Provider<AdmissionsViewState<List<AdmissionsLead>>>((ref) {
  return resolveAdmissionsAsync(
    ref.watch(admissionsLeadsFutureProvider),
    forceLoading: ref.watch(admissionsLeadsLoadingProvider),
    forceError: ref.watch(admissionsLeadsErrorProvider),
    forceEmpty: ref.watch(admissionsLeadsEmptyProvider),
    isDataEmpty: (leads) => leads.isEmpty,
  );
});
