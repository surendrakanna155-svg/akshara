import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/repository_providers.dart';
import '../admissions_models.dart';

final admissionsApplicationsLoadingProvider =
    StateProvider<bool>((ref) => false);
final admissionsApplicationsErrorProvider = StateProvider<bool>((ref) => false);
final admissionsApplicationsEmptyProvider = StateProvider<bool>((ref) => false);

final admissionsApplicationsFilterProvider = StateProvider<int>((ref) => 0);

final admissionsApplicationsProvider =
    Provider<List<AdmissionsApplication>>((ref) {
  if (ref.watch(admissionsApplicationsLoadingProvider)) return const [];
  if (ref.watch(admissionsApplicationsErrorProvider)) return const [];
  if (ref.watch(admissionsApplicationsEmptyProvider)) return const [];
  return ref.read(admissionsRepositoryProvider).getApplications();
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
