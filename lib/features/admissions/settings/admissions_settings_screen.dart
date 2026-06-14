import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/spacing.dart';
import '../../admin/admin_layout.dart';
import '../admissions_async_state.dart';
import '../admissions_models.dart';
import '../admissions_mutations_provider.dart';
import '../admissions_navigation.dart';
import '../admissions_requests.dart';
import '../widgets/admissions_module_scaffold.dart';
import 'admissions_settings_provider.dart';
import 'widgets/admissions_settings_sections.dart';

/// AD-10 — Admissions CRM settings.
class AdmissionsSettingsScreen extends ConsumerStatefulWidget {
  const AdmissionsSettingsScreen({super.key});

  @override
  ConsumerState<AdmissionsSettingsScreen> createState() =>
      _AdmissionsSettingsScreenState();
}

class _AdmissionsSettingsScreenState
    extends ConsumerState<AdmissionsSettingsScreen> {
  AdmissionsSettingsData? _draft;
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final viewState = ref.watch(admissionsSettingsViewStateProvider);
    final isMobile = AdminLayout.isMobile(context);
    final mutationState = ref.watch(updateAdmissionsSettingsProvider);
    final isMutationLoading = mutationState.isLoading;

    return AdmissionsModuleScaffold(
      screen: AdmissionsScreen.settings,
      showFilterBar: false,
      body: AdmissionsAsyncBody<AdmissionsSettingsData>(
        state: viewState,
        loadingLabel: 'Loading admissions settings',
        emptyMessage: 'No settings available.',
        emptyIcon: Icons.settings_outlined,
        onRetry: () =>
            retryAdmissionsFuture(ref, admissionsSettingsFutureProvider),
        builder: (settings) {
          _draft ??= settings;
          final draft = _draft ?? settings;
          if (isMobile) {
            return SingleChildScrollView(
              child: Column(
                children: _sections(
                  context,
                  draft,
                  isMutationLoading || _isSaving,
                ),
              ),
            );
          }
          return Wrap(
            spacing: AksharaSpacing.s4,
            runSpacing: AksharaSpacing.s4,
            children: [
              for (final section in _sections(
                context,
                draft,
                isMutationLoading || _isSaving,
              ))
                SizedBox(width: 540, child: section),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _sections(
    BuildContext context,
    AdmissionsSettingsData settings,
    bool isSaving,
  ) {
    return [
      _SaveSettingsCard(
        isSaving: isSaving,
        onSave: _save,
      ),
      const SizedBox(height: AksharaSpacing.s4),
      AdmissionsLeadStagesSettings(
        stages: settings.leadStages,
        onStageEnabledChanged: (stage, enabled) {
          setState(() {
            _draft = AdmissionsSettingsData(
              leadStages: [
                for (final item in settings.leadStages)
                  if (item.stage == stage)
                    LeadStageConfig(
                      stage: item.stage,
                      enabled: enabled,
                      autoAdvanceDays: item.autoAdvanceDays,
                    )
                  else
                    item,
              ],
              leadScores: settings.leadScores,
              workflowSteps: settings.workflowSteps,
              assignmentRules: settings.assignmentRules,
              notificationTemplates: settings.notificationTemplates,
            );
          });
        },
        onStageAutoAdvanceChanged: (stage, autoAdvanceDays) {
          setState(() {
            _draft = AdmissionsSettingsData(
              leadStages: [
                for (final item in settings.leadStages)
                  if (item.stage == stage)
                    LeadStageConfig(
                      stage: item.stage,
                      enabled: item.enabled,
                      autoAdvanceDays: autoAdvanceDays,
                    )
                  else
                    item,
              ],
              leadScores: settings.leadScores,
              workflowSteps: settings.workflowSteps,
              assignmentRules: settings.assignmentRules,
              notificationTemplates: settings.notificationTemplates,
            );
          });
        },
      ),
      const SizedBox(height: AksharaSpacing.s4),
      AdmissionsLeadScoresSettings(
        scores: settings.leadScores,
        onScoreMinEngagementChanged: (score, minEngagement) {
          setState(() {
            _draft = AdmissionsSettingsData(
              leadStages: settings.leadStages,
              leadScores: [
                for (final item in settings.leadScores)
                  if (item.score == score)
                    LeadScoreConfig(
                      score: item.score,
                      minEngagement: minEngagement,
                      followUpHours: item.followUpHours,
                    )
                  else
                    item,
              ],
              workflowSteps: settings.workflowSteps,
              assignmentRules: settings.assignmentRules,
              notificationTemplates: settings.notificationTemplates,
            );
          });
        },
        onScoreFollowUpHoursChanged: (score, followUpHours) {
          setState(() {
            _draft = AdmissionsSettingsData(
              leadStages: settings.leadStages,
              leadScores: [
                for (final item in settings.leadScores)
                  if (item.score == score)
                    LeadScoreConfig(
                      score: item.score,
                      minEngagement: item.minEngagement,
                      followUpHours: followUpHours,
                    )
                  else
                    item,
              ],
              workflowSteps: settings.workflowSteps,
              assignmentRules: settings.assignmentRules,
              notificationTemplates: settings.notificationTemplates,
            );
          });
        },
      ),
      const SizedBox(height: AksharaSpacing.s4),
      AdmissionsWorkflowSettings(
        steps: settings.workflowSteps,
        onWorkflowEnabledChanged: (status, enabled) {
          setState(() {
            _draft = AdmissionsSettingsData(
              leadStages: settings.leadStages,
              leadScores: settings.leadScores,
              workflowSteps: [
                for (final item in settings.workflowSteps)
                  if (item.status == status)
                    ApplicationWorkflowConfig(
                      status: item.status,
                      enabled: enabled,
                      requiresPrincipalApproval: item.requiresPrincipalApproval,
                    )
                  else
                    item,
              ],
              assignmentRules: settings.assignmentRules,
              notificationTemplates: settings.notificationTemplates,
            );
          });
        },
        onWorkflowPrincipalApprovalChanged: (status, requiresApproval) {
          setState(() {
            _draft = AdmissionsSettingsData(
              leadStages: settings.leadStages,
              leadScores: settings.leadScores,
              workflowSteps: [
                for (final item in settings.workflowSteps)
                  if (item.status == status)
                    ApplicationWorkflowConfig(
                      status: item.status,
                      enabled: item.enabled,
                      requiresPrincipalApproval: requiresApproval,
                    )
                  else
                    item,
              ],
              assignmentRules: settings.assignmentRules,
              notificationTemplates: settings.notificationTemplates,
            );
          });
        },
      ),
      const SizedBox(height: AksharaSpacing.s4),
      AdmissionsAssignmentRulesSettings(
        rules: settings.assignmentRules,
        onRuleEnabledChanged: (ruleId, enabled) {
          setState(() {
            _draft = AdmissionsSettingsData(
              leadStages: settings.leadStages,
              leadScores: settings.leadScores,
              workflowSteps: settings.workflowSteps,
              assignmentRules: [
                for (final item in settings.assignmentRules)
                  if (item.id == ruleId)
                    CounselorAssignmentRule(
                      id: item.id,
                      label: item.label,
                      strategy: item.strategy,
                      enabled: enabled,
                    )
                  else
                    item,
              ],
              notificationTemplates: settings.notificationTemplates,
            );
          });
        },
      ),
      const SizedBox(height: AksharaSpacing.s4),
      AdmissionsNotificationTemplatesSettings(
        templates: settings.notificationTemplates,
        onTemplateEnabledChanged: (templateId, enabled) {
          setState(() {
            _draft = AdmissionsSettingsData(
              leadStages: settings.leadStages,
              leadScores: settings.leadScores,
              workflowSteps: settings.workflowSteps,
              assignmentRules: settings.assignmentRules,
              notificationTemplates: [
                for (final item in settings.notificationTemplates)
                  if (item.id == templateId)
                    NotificationTemplate(
                      id: item.id,
                      name: item.name,
                      channel: item.channel,
                      preview: item.preview,
                      enabled: enabled,
                    )
                  else
                    item,
              ],
            );
          });
        },
      ),
    ];
  }

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null) return;
    final updates = <AdmissionsSettingUpdate>[
      for (final stage in draft.leadStages) ...[
        AdmissionsSettingUpdate(
          sectionId: 'leadStages',
          itemId: '${stage.stage.name}.enabled',
          value: '${stage.enabled}',
        ),
        AdmissionsSettingUpdate(
          sectionId: 'leadStages',
          itemId: '${stage.stage.name}.autoAdvanceDays',
          value: '${stage.autoAdvanceDays ?? ''}',
        ),
      ],
      for (final score in draft.leadScores) ...[
        AdmissionsSettingUpdate(
          sectionId: 'leadScores',
          itemId: '${score.score.name}.minEngagement',
          value: '${score.minEngagement}',
        ),
        AdmissionsSettingUpdate(
          sectionId: 'leadScores',
          itemId: '${score.score.name}.followUpHours',
          value: '${score.followUpHours}',
        ),
      ],
      for (final step in draft.workflowSteps) ...[
        AdmissionsSettingUpdate(
          sectionId: 'workflowSteps',
          itemId: '${step.status.name}.enabled',
          value: '${step.enabled}',
        ),
        AdmissionsSettingUpdate(
          sectionId: 'workflowSteps',
          itemId: '${step.status.name}.requiresPrincipalApproval',
          value: '${step.requiresPrincipalApproval}',
        ),
      ],
      for (final rule in draft.assignmentRules)
        AdmissionsSettingUpdate(
          sectionId: 'assignmentRules',
          itemId: '${rule.id}.enabled',
          value: '${rule.enabled}',
        ),
      for (final template in draft.notificationTemplates)
        AdmissionsSettingUpdate(
          sectionId: 'notificationTemplates',
          itemId: '${template.id}.enabled',
          value: '${template.enabled}',
        ),
    ];
    setState(() => _isSaving = true);
    try {
      await ref.read(updateAdmissionsSettingsProvider.notifier).execute(
            UpdateAdmissionsSettingsRequest(updates: updates),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Admissions settings saved')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}

class _SaveSettingsCard extends StatelessWidget {
  const _SaveSettingsCard({required this.isSaving, required this.onSave});

  final bool isSaving;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: FilledButton.icon(
        onPressed: isSaving ? null : onSave,
        icon: isSaving
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.save_outlined),
        label: Text(isSaving ? 'Saving...' : 'Save settings'),
      ),
    );
  }
}
