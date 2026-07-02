import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_text.dart';
import '../../../core/security/permissions.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/widgets/akshara_manage_action.dart';
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
    final mutationState = ref.watch(saveAdmissionsSettingsProvider);
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
    setState(() => _isSaving = true);
    try {
      // #6: persist the full settings snapshot via POST /admissions/settings.
      // The whole edited draft is sent at once — no per-item update fan-out —
      // and the notifier round-trips it back through GET for a lossless save.
      await ref.read(saveAdmissionsSettingsProvider.notifier).execute(
            SaveAdmissionsSettingsRequest(settings: draft),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          key: QaTestKeys.admissionsSettingsSavedSnackbar,
          content: Text('Admissions settings saved'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(aksharaErrorMessage(error))),
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
      child: AksharaManageAction(
        permission: Permission.manageAdmissions,
        child: FilledButton.icon(
          key: QaTestKeys.admissionsSettingsSaveButton,
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
      ),
    );
  }
}
