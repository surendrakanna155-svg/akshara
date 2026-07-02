import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_future.dart';
import '../../../core/repositories/paginated_result.dart';
import '../../../core/repositories/repository_query.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/tenant/tenant_provider.dart';
import '../admissions_async_state.dart';
import '../admissions_models.dart';

final admissionsLeadsLoadingProvider = StateProvider<bool>((ref) => false);
final admissionsLeadsErrorProvider = StateProvider<bool>((ref) => false);
final admissionsLeadsEmptyProvider = StateProvider<bool>((ref) => false);
final admissionsLeadsFilterProvider = StateProvider<int>((ref) => 0);
final admissionsLeadsPageProvider = StateProvider<int>((ref) => 1);

/// ADM-3: the set of lead ids the operator has ticked for a bulk action.
/// Cleared after a successful bulk action or when leads reload.
final admissionsSelectedLeadsProvider =
    StateProvider<Set<String>>((ref) => <String>{});

final admissionsLeadsQueryProvider = Provider<RepositoryQuery>((ref) {
  final baseQuery = ref.watch(repositoryQueryProvider);
  final page = ref.watch(admissionsLeadsPageProvider);
  return baseQuery.withPage(page);
});

final admissionsLeadsFutureProvider =
    FutureProvider<PaginatedResult<AdmissionsLead>>((ref) async {
  return ref.read(admissionsRepositoryProvider).getLeads(
        query: ref.watch(admissionsLeadsQueryProvider),
      );
});

final admissionsLeadsPageResultProvider =
    Provider<PaginatedResult<AdmissionsLead>?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(admissionsLeadsFutureProvider),
    manualLoading: ref.watch(admissionsLeadsLoadingProvider),
    manualError: ref.watch(admissionsLeadsErrorProvider),
    manualEmpty: ref.watch(admissionsLeadsEmptyProvider),
  );
});

final admissionsLeadsProvider = Provider<List<AdmissionsLead>>((ref) {
  return ref.watch(admissionsLeadsPageResultProvider)?.items ?? const [];
});

final admissionsLeadsViewStateProvider =
    Provider<AdmissionsViewState<PaginatedResult<AdmissionsLead>>>((ref) {
  return resolveAdmissionsAsync(
    ref.watch(admissionsLeadsFutureProvider),
    forceLoading: ref.watch(admissionsLeadsLoadingProvider),
    forceError: ref.watch(admissionsLeadsErrorProvider),
    forceEmpty: ref.watch(admissionsLeadsEmptyProvider),
    isDataEmpty: (result) => result.items.isEmpty,
  );
});
