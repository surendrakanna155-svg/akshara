import 'package:flutter/material.dart';

import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import '../../admissions_models.dart';
import '../../widgets/admissions_stage_badge.dart';

/// Settings configuration sections for AD-10.
class AdmissionsLeadStagesSettings extends StatelessWidget {
  const AdmissionsLeadStagesSettings({super.key, required this.stages});

  final List<LeadStageConfig> stages;

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
              onChanged: (_) {},
            ),
        ],
      ),
    );
  }
}

class AdmissionsLeadScoresSettings extends StatelessWidget {
  const AdmissionsLeadScoresSettings({super.key, required this.scores});

  final List<LeadScoreConfig> scores;

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
              onTap: () {},
            ),
        ],
      ),
    );
  }
}

class AdmissionsWorkflowSettings extends StatelessWidget {
  const AdmissionsWorkflowSettings({super.key, required this.steps});

  final List<ApplicationWorkflowConfig> steps;

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
              onChanged: (_) {},
            ),
        ],
      ),
    );
  }
}

class AdmissionsAssignmentRulesSettings extends StatelessWidget {
  const AdmissionsAssignmentRulesSettings({super.key, required this.rules});

  final List<CounselorAssignmentRule> rules;

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
              onChanged: (_) {},
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
  });

  final List<NotificationTemplate> templates;

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
              onChanged: (_) {},
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
