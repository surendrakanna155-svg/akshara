import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/spacing.dart';
import '../../admin/admin_layout.dart';
import '../admissions_async_state.dart';
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
    final viewState = ref.watch(admissionsSettingsViewStateProvider);
    final isMobile = AdminLayout.isMobile(context);

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
          if (isMobile) {
            return Column(children: _sections(settings));
          }
          return Wrap(
            spacing: AksharaSpacing.s4,
            runSpacing: AksharaSpacing.s4,
            children: [
              for (final section in _sections(settings))
                SizedBox(width: 540, child: section),
            ],
          );
        },
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
