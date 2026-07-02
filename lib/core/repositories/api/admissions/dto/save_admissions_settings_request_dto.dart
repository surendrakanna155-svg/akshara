import '../../../../../features/admissions/admissions_models.dart';
import 'admissions_enum_codec.dart';

/// #6: serializes the full admissions settings snapshot for
/// `POST /admissions/settings`. The body mirrors the exact shape that
/// `GET /admissions/settings` returns, so a round-trip (load → edit → save →
/// reload) is lossless. The backend accepts either the settings object directly
/// or wrapped under `settings`; we send it directly.
class SaveAdmissionsSettingsRequestDto {
  const SaveAdmissionsSettingsRequestDto({required this.raw});

  factory SaveAdmissionsSettingsRequestDto.fromDomain(
    AdmissionsSettingsData settings,
  ) {
    return SaveAdmissionsSettingsRequestDto(
      raw: {
        'leadStages': [
          for (final stage in settings.leadStages)
            {
              'stage': AdmissionsEnumCodec.leadStageToApi(stage.stage),
              'enabled': stage.enabled,
              'autoAdvanceDays': stage.autoAdvanceDays,
            },
        ],
        'leadScores': [
          for (final score in settings.leadScores)
            {
              'score': _leadScoreToApi(score.score),
              'minEngagement': score.minEngagement,
              'followUpHours': score.followUpHours,
            },
        ],
        'workflowSteps': [
          for (final step in settings.workflowSteps)
            {
              'status': _applicationStatusToApi(step.status),
              'enabled': step.enabled,
              'requiresPrincipalApproval': step.requiresPrincipalApproval,
            },
        ],
        'assignmentRules': [
          for (final rule in settings.assignmentRules)
            {
              'id': rule.id,
              'label': rule.label,
              'strategy': rule.strategy,
              'enabled': rule.enabled,
            },
        ],
        'notificationTemplates': [
          for (final template in settings.notificationTemplates)
            {
              'id': template.id,
              'name': template.name,
              'channel': template.channel,
              'preview': template.preview,
              'enabled': template.enabled,
            },
        ],
      },
    );
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;

  static String _leadScoreToApi(LeadScore score) => switch (score) {
        LeadScore.hot => 'hot',
        LeadScore.warm => 'warm',
        LeadScore.cold => 'cold',
      };

  static String _applicationStatusToApi(ApplicationStatus status) =>
      switch (status) {
        ApplicationStatus.draft => 'draft',
        ApplicationStatus.submitted => 'submitted',
        ApplicationStatus.documentsPending => 'documents_pending',
        ApplicationStatus.underReview => 'under_review',
        ApplicationStatus.approved => 'approved',
        ApplicationStatus.rejected => 'rejected',
      };
}
