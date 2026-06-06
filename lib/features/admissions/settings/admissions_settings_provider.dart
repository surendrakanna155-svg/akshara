import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../admissions_models.dart';

final admissionsSettingsLoadingProvider = StateProvider<bool>((ref) => false);
final admissionsSettingsErrorProvider = StateProvider<bool>((ref) => false);

final admissionsSettingsProvider = Provider<AdmissionsSettingsData?>((ref) {
  if (ref.watch(admissionsSettingsLoadingProvider)) return null;
  if (ref.watch(admissionsSettingsErrorProvider)) return null;
  return _mockSettings();
});

AdmissionsSettingsData _mockSettings() {
  return AdmissionsSettingsData(
    leadStages: [
      for (final stage in LeadStage.values)
        if (stage != LeadStage.lost)
          LeadStageConfig(
            stage: stage,
            enabled: true,
            autoAdvanceDays: switch (stage) {
              LeadStage.newEnquiry => 3,
              LeadStage.contacted => 5,
              LeadStage.schoolVisit => 7,
              _ => null,
            },
          ),
    ],
    leadScores: const [
      LeadScoreConfig(score: LeadScore.hot, minEngagement: 80, followUpHours: 4),
      LeadScoreConfig(score: LeadScore.warm, minEngagement: 50, followUpHours: 24),
      LeadScoreConfig(score: LeadScore.cold, minEngagement: 20, followUpHours: 72),
    ],
    workflowSteps: const [
      ApplicationWorkflowConfig(
        status: ApplicationStatus.draft,
        enabled: true,
        requiresPrincipalApproval: false,
      ),
      ApplicationWorkflowConfig(
        status: ApplicationStatus.submitted,
        enabled: true,
        requiresPrincipalApproval: false,
      ),
      ApplicationWorkflowConfig(
        status: ApplicationStatus.documentsPending,
        enabled: true,
        requiresPrincipalApproval: false,
      ),
      ApplicationWorkflowConfig(
        status: ApplicationStatus.underReview,
        enabled: true,
        requiresPrincipalApproval: true,
      ),
      ApplicationWorkflowConfig(
        status: ApplicationStatus.approved,
        enabled: true,
        requiresPrincipalApproval: false,
      ),
    ],
    assignmentRules: const [
      CounselorAssignmentRule(
        id: 'rule_1',
        label: 'Round-robin by class band',
        strategy: 'Round-robin · Primary vs Secondary',
        enabled: true,
      ),
      CounselorAssignmentRule(
        id: 'rule_2',
        label: 'Walk-in desk assignment',
        strategy: 'First available counselor',
        enabled: true,
      ),
      CounselorAssignmentRule(
        id: 'rule_3',
        label: 'Marketing campaign owner',
        strategy: 'Retain campaign counselor',
        enabled: false,
      ),
    ],
    notificationTemplates: const [
      NotificationTemplate(
        id: 'tpl_1',
        name: 'Visit reminder',
        channel: 'WhatsApp',
        preview: 'Reminder: School visit scheduled for {{date}} at {{time}}.',
        enabled: true,
      ),
      NotificationTemplate(
        id: 'tpl_2',
        name: 'Application received',
        channel: 'SMS',
        preview: 'We received {{student}} application. Ref: {{app_id}}.',
        enabled: true,
      ),
      NotificationTemplate(
        id: 'tpl_3',
        name: 'Admission approved',
        channel: 'Email',
        preview: 'Congratulations! {{student}} admission is approved.',
        enabled: true,
      ),
    ],
  );
}
