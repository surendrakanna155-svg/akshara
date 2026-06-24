import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/repository_providers.dart';
import '../../../core/tenant/tenant_provider.dart';
import '../admissions_models.dart';

final admissionsLeadDetailLoadingProvider =
    StateProvider.family<bool, String>((ref, _) => false);
final admissionsLeadDetailErrorProvider =
    StateProvider.family<bool, String>((ref, _) => false);
final admissionsLeadDetailEmptyProvider =
    StateProvider.family<bool, String>((ref, _) => false);

/// Real lead-detail fetch — pulls the lead with its persisted activity timeline
/// and follow-up history from the backend (`GET /admissions/leads/{id}`).
final admissionsLeadDetailDataProvider =
    FutureProvider.family<LeadDetailData, String>((ref, leadId) async {
  final query = ref.watch(repositoryQueryProvider);
  return ref
      .read(admissionsRepositoryProvider)
      .getLeadDetail(query: query, leadId: leadId);
});

final admissionsLeadDetailProvider =
    Provider.family<LeadDetailProfile?, String>((ref, leadId) {
  if (ref.watch(admissionsLeadDetailLoadingProvider(leadId))) return null;
  if (ref.watch(admissionsLeadDetailErrorProvider(leadId))) return null;
  if (ref.watch(admissionsLeadDetailEmptyProvider(leadId))) return null;

  final data = ref.watch(admissionsLeadDetailDataProvider(leadId)).valueOrNull;
  if (data == null) return null;

  return _buildLeadDetail(data);
});

LeadDetailProfile _buildLeadDetail(LeadDetailData data) {
  final lead = data.lead;
  const activeStages = [
    LeadStage.newEnquiry,
    LeadStage.contacted,
    LeadStage.schoolVisit,
    LeadStage.demoClass,
    LeadStage.followUp,
    LeadStage.admissionConfirmed,
    LeadStage.joined,
  ];

  final currentIndex = activeStages.indexOf(lead.stage);

  final statusSteps = [
    for (var i = 0; i < activeStages.length; i++)
      LeadStatusStep(
        stage: activeStages[i],
        isComplete: currentIndex > i,
        isCurrent: currentIndex == i,
        completedLabel: currentIndex > i ? 'Completed' : null,
      ),
  ];

  return LeadDetailProfile(
    lead: lead,
    email: data.email,
    address: data.address,
    createdLabel: data.createdLabel,
    lastActivityLabel: data.lastActivityLabel,
    notes: data.notes,
    availableCounselors: const [
      'Meera N.',
      'Rahul V.',
      'Sneha K.',
      'Arun D.',
    ],
    statusSteps: statusSteps,
    acquisitionReadOnly: true,
    activities: data.activities,
    followUpHistory: data.followUpHistory,
  );
}
