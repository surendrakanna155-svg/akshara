import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_future.dart';
import '../../../core/repositories/paginated_result.dart';
import '../../../core/repositories/repository_query.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/tenant/tenant_provider.dart';
import '../admissions_async_state.dart';
import '../admissions_models.dart';

final admissionsApplicationsLoadingProvider =
    StateProvider<bool>((ref) => false);
final admissionsApplicationsErrorProvider = StateProvider<bool>((ref) => false);
final admissionsApplicationsEmptyProvider = StateProvider<bool>((ref) => false);
final admissionsApplicationsFilterProvider = StateProvider<int>((ref) => 0);
final admissionsApplicationsPageProvider = StateProvider<int>((ref) => 1);

final admissionsApplicationsQueryProvider = Provider<RepositoryQuery>((ref) {
  final baseQuery = ref.watch(repositoryQueryProvider);
  final page = ref.watch(admissionsApplicationsPageProvider);
  return baseQuery.withPage(page);
});

final admissionsApplicationsFutureProvider =
    FutureProvider<PaginatedResult<AdmissionsApplication>>((ref) async {
  return ref
      .read(admissionsRepositoryProvider)
      .getApplications(query: ref.watch(admissionsApplicationsQueryProvider));
});

final admissionsApplicationsPageResultProvider =
    Provider<PaginatedResult<AdmissionsApplication>?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(admissionsApplicationsFutureProvider),
    manualLoading: ref.watch(admissionsApplicationsLoadingProvider),
    manualError: ref.watch(admissionsApplicationsErrorProvider),
    manualEmpty: ref.watch(admissionsApplicationsEmptyProvider),
  );
});

final admissionsApplicationsProvider =
    Provider<List<AdmissionsApplication>>((ref) {
  return ref.watch(admissionsApplicationsPageResultProvider)?.items ??
      const [];
});

final admissionsApplicationsViewStateProvider =
    Provider<AdmissionsViewState<PaginatedResult<AdmissionsApplication>>>(
        (ref) {
  return resolveAdmissionsAsync(
    ref.watch(admissionsApplicationsFutureProvider),
    forceLoading: ref.watch(admissionsApplicationsLoadingProvider),
    forceError: ref.watch(admissionsApplicationsErrorProvider),
    forceEmpty: ref.watch(admissionsApplicationsEmptyProvider),
    isDataEmpty: (result) => result.items.isEmpty,
  );
});

final admissionsApplicationWorkflowProvider =
    Provider<ApplicationWorkflowSummary>((ref) {
  final apps = ref.watch(admissionsApplicationsProvider);
  if (apps.isEmpty && !ref.watch(admissionsApplicationsEmptyProvider)) {
    return const ApplicationWorkflowSummary(
      draft: 0,
      submitted: 0,
      underReview: 0,
      approved: 0,
    );
  }

  var draft = 0;
  var submitted = 0;
  var underReview = 0;
  var approved = 0;

  for (final app in apps) {
    switch (app.status) {
      case ApplicationStatus.draft:
        draft++;
      case ApplicationStatus.submitted:
      case ApplicationStatus.documentsPending:
        submitted++;
      case ApplicationStatus.underReview:
        underReview++;
      case ApplicationStatus.approved:
        approved++;
      case ApplicationStatus.rejected:
        underReview++;
    }
  }

  return ApplicationWorkflowSummary(
    draft: draft,
    submitted: submitted,
    underReview: underReview,
    approved: approved,
  );
});
