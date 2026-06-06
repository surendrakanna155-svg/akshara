import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  return _mockApplications();
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

List<AdmissionsApplication> _mockApplications() {
  return const [
    AdmissionsApplication(
      id: 'APP-2208',
      studentName: 'Ananya Reddy',
      classLabel: '5',
      parentName: 'Rajesh Reddy',
      submittedLabel: '4 Jun 2026',
      status: ApplicationStatus.underReview,
      documentsComplete: 4,
      documentsTotal: 5,
      counselor: 'Meera N.',
    ),
    AdmissionsApplication(
      id: 'APP-2201',
      studentName: 'Karthik Sharma',
      classLabel: '8',
      parentName: 'Lakshmi Sharma',
      submittedLabel: '3 Jun 2026',
      status: ApplicationStatus.documentsPending,
      documentsComplete: 2,
      documentsTotal: 5,
      counselor: 'Rahul V.',
    ),
    AdmissionsApplication(
      id: 'APP-2194',
      studentName: 'Priya Menon',
      classLabel: '3',
      parentName: 'Suresh Menon',
      submittedLabel: '2 Jun 2026',
      status: ApplicationStatus.submitted,
      documentsComplete: 5,
      documentsTotal: 5,
      counselor: 'Meera N.',
    ),
    AdmissionsApplication(
      id: 'APP-2188',
      studentName: 'Arjun Patel',
      classLabel: '10',
      parentName: 'Anita Patel',
      submittedLabel: '1 Jun 2026',
      status: ApplicationStatus.approved,
      documentsComplete: 5,
      documentsTotal: 5,
      counselor: 'Sneha K.',
    ),
    AdmissionsApplication(
      id: 'APP-2180',
      studentName: 'Divya Iyer',
      classLabel: '6',
      parentName: 'Vikram Iyer',
      submittedLabel: '—',
      status: ApplicationStatus.draft,
      documentsComplete: 0,
      documentsTotal: 5,
      counselor: 'Arun D.',
    ),
    AdmissionsApplication(
      id: 'APP-2175',
      studentName: 'Emma Thomas',
      classLabel: '7',
      parentName: 'Joseph Thomas',
      submittedLabel: '28 May 2026',
      status: ApplicationStatus.rejected,
      documentsComplete: 3,
      documentsTotal: 5,
      counselor: 'Sneha K.',
    ),
  ];
}
