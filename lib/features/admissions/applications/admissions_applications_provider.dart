import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/tenant/tenant_provider.dart';
import '../../../core/providers/repository_future.dart';
import '../../../core/repositories/repository_providers.dart';
import '../admissions_async_state.dart';
import '../admissions_models.dart';

final admissionsApplicationsLoadingProvider =
    StateProvider<bool>((ref) => false);
final admissionsApplicationsErrorProvider = StateProvider<bool>((ref) => false);
final admissionsApplicationsEmptyProvider = StateProvider<bool>((ref) => false);

final admissionsApplicationsFilterProvider = StateProvider<int>((ref) => 0);

final admissionsApplicationsFutureProvider =
    FutureProvider<List<AdmissionsApplication>>((ref) async {
  return ref
      .read(admissionsRepositoryProvider)
      .getApplications(query: ref.watch(repositoryQueryProvider));
});

final admissionsApplicationsProvider =
    Provider<List<AdmissionsApplication>>((ref) {
  return watchRepositoryFuture(
        ref,
        ref.watch(admissionsApplicationsFutureProvider),
        manualLoading: ref.watch(admissionsApplicationsLoadingProvider),
        manualError: ref.watch(admissionsApplicationsErrorProvider),
        manualEmpty: ref.watch(admissionsApplicationsEmptyProvider),
      ) ??
      const [];
});

final admissionsApplicationsViewStateProvider =
    Provider<AdmissionsViewState<List<AdmissionsApplication>>>((ref) {
  return resolveAdmissionsAsync(
    ref.watch(admissionsApplicationsFutureProvider),
    forceLoading: ref.watch(admissionsApplicationsLoadingProvider),
    forceError: ref.watch(admissionsApplicationsErrorProvider),
    forceEmpty: ref.watch(admissionsApplicationsEmptyProvider),
    isDataEmpty: (apps) => apps.isEmpty,
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
