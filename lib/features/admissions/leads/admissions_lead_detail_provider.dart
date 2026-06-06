import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../admissions_models.dart';
import 'admissions_leads_provider.dart';

final admissionsLeadDetailLoadingProvider =
    StateProvider.family<bool, String>((ref, _) => false);
final admissionsLeadDetailErrorProvider =
    StateProvider.family<bool, String>((ref, _) => false);
final admissionsLeadDetailEmptyProvider =
    StateProvider.family<bool, String>((ref, _) => false);

final admissionsLeadDetailProvider =
    Provider.family<LeadDetailProfile?, String>((ref, leadId) {
  if (ref.watch(admissionsLeadDetailLoadingProvider(leadId))) return null;
  if (ref.watch(admissionsLeadDetailErrorProvider(leadId))) return null;
  if (ref.watch(admissionsLeadDetailEmptyProvider(leadId))) return null;

  final leads = ref.watch(admissionsLeadsProvider);
  AdmissionsLead? lead;
  for (final item in leads) {
    if (item.id == leadId) {
      lead = item;
      break;
    }
  }
  if (lead == null) return null;

  return _buildLeadDetail(lead);
});

LeadDetailProfile _buildLeadDetail(AdmissionsLead lead) {
  final activeStages = [
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
    email: '${lead.parentName.split(' ').first.toLowerCase()}@email.com',
    address: '12, Lake View Colony, Hyderabad',
    createdLabel: '28 May 2026',
    lastActivityLabel: '4 Jun 2026 · 3:15 PM',
    notes:
        'Parent interested in CBSE curriculum. Prefers morning batch. Requested fee structure.',
    availableCounselors: const [
      'Meera N.',
      'Rahul V.',
      'Sneha K.',
      'Arun D.',
    ],
    statusSteps: statusSteps,
    acquisitionReadOnly: true,
    activities: [
      LeadActivityItem(
        id: 'act_1',
        timestampLabel: '4 Jun · 3:15 PM',
        title: 'School visit completed',
        description: 'Campus tour with both parents. Positive feedback on labs.',
        actor: lead.counselor,
        type: LeadActivityType.visit,
      ),
      LeadActivityItem(
        id: 'act_2',
        timestampLabel: '3 Jun · 11:00 AM',
        title: 'WhatsApp brochure sent',
        description: 'Shared fee plan and curriculum PDF.',
        actor: lead.counselor,
        type: LeadActivityType.whatsapp,
      ),
      LeadActivityItem(
        id: 'act_3',
        timestampLabel: '1 Jun · 10:30 AM',
        title: 'Stage moved to ${lead.stage.label}',
        description: 'Pipeline updated after phone screening.',
        actor: lead.counselor,
        type: LeadActivityType.stageChange,
      ),
      LeadActivityItem(
        id: 'act_4',
        timestampLabel: '28 May · 4:45 PM',
        title: 'Lead created from ${lead.source.label}',
        description: 'Campaign: ${lead.campaign}',
        actor: 'System',
        type: LeadActivityType.note,
      ),
    ],
    followUpHistory: [
      LeadFollowUpRecord(
        id: 'fh_1',
        scheduledLabel: '5 Jun · 10:00 AM',
        completedLabel: '—',
        task: 'Discuss fee plan and transport options',
        counselor: lead.counselor,
        status: FollowUpStatus.pending,
        outcome: 'Scheduled',
      ),
      LeadFollowUpRecord(
        id: 'fh_2',
        scheduledLabel: '3 Jun · 11:00 AM',
        completedLabel: '3 Jun · 11:20 AM',
        task: 'Post-visit follow-up call',
        counselor: lead.counselor,
        status: FollowUpStatus.completed,
        outcome: 'Parent requested application form',
      ),
      LeadFollowUpRecord(
        id: 'fh_3',
        scheduledLabel: '30 May · 2:00 PM',
        completedLabel: '30 May · 2:10 PM',
        task: 'Initial counselling call',
        counselor: lead.counselor,
        status: FollowUpStatus.completed,
        outcome: 'Visit scheduled for 4 Jun',
      ),
    ],
  );
}
