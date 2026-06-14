import 'package:flutter/material.dart';

import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import '../../admissions_models.dart';
import '../../widgets/admissions_stage_badge.dart';

/// Settings configuration sections for AD-10.
class AdmissionsLeadStagesSettings extends StatelessWidget {
  const AdmissionsLeadStagesSettings({
    super.key,
    required this.stages,
    required this.onStageEnabledChanged,
    required this.onStageAutoAdvanceChanged,
  });

  final List<LeadStageConfig> stages;
  final void Function(LeadStage stage, bool enabled) onStageEnabledChanged;
  final void Function(LeadStage stage, int? autoAdvanceDays)
      onStageAutoAdvanceChanged;

  @override
  Widget build(BuildContext context) {
    return _SettingsSection(
      title: 'Lead stages',
      semanticLabel: 'Lead stages configuration',
      child: Column(
        children: [
          for (final config in stages)
            SwitchListTile(
              title: AdmissionsStageBadge(stage: config.stage),
              subtitle: Text(
                config.autoAdvanceDays == null
                    ? 'No auto-advance'
                    : 'Auto-advance after ${config.autoAdvanceDays} days',
              ),
              value: config.enabled,
              onChanged: (value) => onStageEnabledChanged(config.stage, value),
            ),
          for (final config in stages)
            Padding(
              padding: const EdgeInsets.only(
                left: AksharaSpacing.s4,
                right: AksharaSpacing.s4,
                bottom: AksharaSpacing.s2,
              ),
              child: TextFormField(
                initialValue: config.autoAdvanceDays?.toString() ?? '',
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: '${config.stage.label} auto-advance days',
                  hintText: 'Leave empty to disable',
                ),
                onChanged: (value) => onStageAutoAdvanceChanged(
                  config.stage,
                  int.tryParse(value.trim()),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class AdmissionsLeadScoresSettings extends StatelessWidget {
  const AdmissionsLeadScoresSettings({
    super.key,
    required this.scores,
    required this.onScoreMinEngagementChanged,
    required this.onScoreFollowUpHoursChanged,
  });

  final List<LeadScoreConfig> scores;
  final void Function(LeadScore score, int minEngagement)
      onScoreMinEngagementChanged;
  final void Function(LeadScore score, int followUpHours)
      onScoreFollowUpHoursChanged;

  @override
  Widget build(BuildContext context) {
    return _SettingsSection(
      title: 'Lead score rules',
      semanticLabel: 'Lead score configuration',
      child: Column(
        children: [
          for (final config in scores)
            ListTile(
              title: Text('${config.score.label} lead'),
              subtitle: Text(
                'Min engagement ${config.minEngagement}% · Follow-up every ${config.followUpHours}h',
              ),
              trailing: const Icon(Icons.tune),
              onTap: null,
            ),
          for (final config in scores)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AksharaSpacing.s4,
                vertical: AksharaSpacing.s1,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: config.minEngagement.toString(),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: '${config.score.label} min engagement %',
                      ),
                      onChanged: (value) {
                        final parsed = int.tryParse(value.trim());
                        if (parsed != null) {
                          onScoreMinEngagementChanged(config.score, parsed);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: AksharaSpacing.s2),
                  Expanded(
                    child: TextFormField(
                      initialValue: config.followUpHours.toString(),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: '${config.score.label} follow-up (h)',
                      ),
                      onChanged: (value) {
                        final parsed = int.tryParse(value.trim());
                        if (parsed != null) {
                          onScoreFollowUpHoursChanged(config.score, parsed);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class AdmissionsWorkflowSettings extends StatelessWidget {
  const AdmissionsWorkflowSettings({
    super.key,
    required this.steps,
    required this.onWorkflowEnabledChanged,
    required this.onWorkflowPrincipalApprovalChanged,
  });

  final List<ApplicationWorkflowConfig> steps;
  final void Function(ApplicationStatus status, bool enabled)
      onWorkflowEnabledChanged;
  final void Function(ApplicationStatus status, bool requiresApproval)
      onWorkflowPrincipalApprovalChanged;

  @override
  Widget build(BuildContext context) {
    return _SettingsSection(
      title: 'Application workflow',
      semanticLabel: 'Application workflow configuration',
      child: Column(
        children: [
          for (final step in steps)
            SwitchListTile(
              title: Text(step.status.label),
              subtitle: Text(
                step.requiresPrincipalApproval
                    ? 'Requires principal approval'
                    : 'Counselor managed',
              ),
              value: step.enabled,
              onChanged: (value) =>
                  onWorkflowEnabledChanged(step.status, value),
            ),
          for (final step in steps)
            SwitchListTile(
              title: Text('${step.status.label} principal approval'),
              subtitle: const Text('Enable principal gate for this status'),
              value: step.requiresPrincipalApproval,
              onChanged: (value) =>
                  onWorkflowPrincipalApprovalChanged(step.status, value),
            ),
        ],
      ),
    );
  }
}

class AdmissionsAssignmentRulesSettings extends StatelessWidget {
  const AdmissionsAssignmentRulesSettings({
    super.key,
    required this.rules,
    required this.onRuleEnabledChanged,
  });

  final List<CounselorAssignmentRule> rules;
  final void Function(String ruleId, bool enabled) onRuleEnabledChanged;

  @override
  Widget build(BuildContext context) {
    return _SettingsSection(
      title: 'Counselor assignment',
      semanticLabel: 'Counselor assignment rules',
      child: Column(
        children: [
          for (final rule in rules)
            SwitchListTile(
              title: Text(rule.label),
              subtitle: Text(rule.strategy),
              value: rule.enabled,
              onChanged: (value) => onRuleEnabledChanged(rule.id, value),
            ),
        ],
      ),
    );
  }
}

class AdmissionsNotificationTemplatesSettings extends StatelessWidget {
  const AdmissionsNotificationTemplatesSettings({
    super.key,
    required this.templates,
    required this.onTemplateEnabledChanged,
  });

  final List<NotificationTemplate> templates;
  final void Function(String templateId, bool enabled) onTemplateEnabledChanged;

  @override
  Widget build(BuildContext context) {
    return _SettingsSection(
      title: 'Notification templates',
      semanticLabel: 'Notification templates configuration',
      child: Column(
        children: [
          for (final template in templates)
            SwitchListTile(
              title: Text(template.name),
              subtitle: Text('${template.channel} · ${template.preview}'),
              value: template.enabled,
              onChanged: (value) =>
                  onTemplateEnabledChanged(template.id, value),
            ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.semanticLabel,
    required this.child,
  });

  final String title;
  final String semanticLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;

    return Semantics(
      container: true,
      label: semanticLabel,
      child: Material(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AksharaSpacing.s3),
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: text.titleSmall.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AksharaSpacing.s3),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
