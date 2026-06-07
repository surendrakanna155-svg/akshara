import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/tenant/tenant_provider.dart';
import '../../../core/providers/repository_future.dart';

import '../../../core/repositories/repository_providers.dart';
import '../admissions_async_state.dart';
import '../admissions_models.dart';

final admissionsReportsLoadingProvider = StateProvider<bool>((ref) => false);
final admissionsReportsErrorProvider = StateProvider<bool>((ref) => false);
final admissionsReportsEmptyProvider = StateProvider<bool>((ref) => false);

final admissionsReportsTabProvider = StateProvider<AdmissionsReportTab>(
  (ref) => AdmissionsReportTab.funnel,
);

final admissionsReportsFutureProvider = FutureProvider<AdmissionsReportsData>((ref) async {
return await ref.read(admissionsRepositoryProvider).getReports(query: ref.watch(repositoryQueryProvider));
});

final admissionsReportsProvider = Provider<AdmissionsReportsData?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(admissionsReportsFutureProvider),
    manualLoading: ref.watch(admissionsReportsLoadingProvider), manualError: ref.watch(admissionsReportsErrorProvider), manualEmpty: ref.watch(admissionsReportsEmptyProvider),
  );
});

final admissionsReportsViewStateProvider =
    Provider<AdmissionsViewState<AdmissionsReportsData>>((ref) {
  return resolveAdmissionsAsync(
    ref.watch(admissionsReportsFutureProvider),
    forceLoading: ref.watch(admissionsReportsLoadingProvider),
    forceError: ref.watch(admissionsReportsErrorProvider),
    forceEmpty: ref.watch(admissionsReportsEmptyProvider),
  );
});
