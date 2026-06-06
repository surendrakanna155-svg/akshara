import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/akshara_error_state.dart';
import '../../../shared/widgets/akshara_loading_state.dart';
import '../../../theme/spacing.dart';
import '../../admin/admin_layout.dart';
import '../admissions_models.dart';
import '../admissions_navigation.dart';
import '../widgets/admissions_module_scaffold.dart';
import 'admissions_settings_provider.dart';
import 'widgets/admissions_settings_sections.dart';

/// AD-10 — Admissions CRM settings.
class AdmissionsSettingsScreen extends ConsumerWidget {
  const AdmissionsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(admissionsSettingsLoadingProvider);
    final isError = ref.watch(admissionsSettingsErrorProvider);
    final settings = ref.watch(admissionsSettingsProvider);
    final isMobile = AdminLayout.isMobile(context);

    return AdmissionsModuleScaffold(
      screen: AdmissionsScreen.settings,
      showFilterBar: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
              child: AksharaLoadingState(
                semanticLabel: 'Loading admissions settings',
              ),
            )
          else if (isError)
            const AksharaErrorState(
              message: 'Unable to load admissions settings.',
            )
          else if (settings == null)
            const SizedBox.shrink()
          else if (isMobile)
            Column(
              children: _sections(settings),
            )
          else
            Wrap(
              spacing: AksharaSpacing.s4,
              runSpacing: AksharaSpacing.s4,
              children: [
                for (final section in _sections(settings))
                  SizedBox(width: 540, child: section),
              ],
            ),
        ],
      ),
    );
  }

  List<Widget> _sections(AdmissionsSettingsData settings) {
    return [
      AdmissionsLeadStagesSettings(stages: settings.leadStages),
      const SizedBox(height: AksharaSpacing.s4),
      AdmissionsLeadScoresSettings(scores: settings.leadScores),
      const SizedBox(height: AksharaSpacing.s4),
      AdmissionsWorkflowSettings(steps: settings.workflowSteps),
      const SizedBox(height: AksharaSpacing.s4),
      AdmissionsAssignmentRulesSettings(rules: settings.assignmentRules),
      const SizedBox(height: AksharaSpacing.s4),
      AdmissionsNotificationTemplatesSettings(
        templates: settings.notificationTemplates,
      ),
    ];
  }
}
