import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/akshara_empty_state.dart';
import '../../../shared/widgets/akshara_error_state.dart';
import '../../../shared/widgets/akshara_loading_state.dart';
import '../../../theme/spacing.dart';
import '../admissions_navigation.dart';
import '../widgets/admissions_module_scaffold.dart';
import 'admissions_applications_provider.dart';
import 'widgets/admissions_application_workflow.dart';
import 'widgets/admissions_applications_table.dart';

/// AD-03 — Applications management with status workflow.
class AdmissionsApplicationsScreen extends ConsumerWidget {
  const AdmissionsApplicationsScreen({super.key});

  static const List<String> filterLabels = [
    'All statuses',
    'All classes',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(admissionsApplicationsLoadingProvider);
    final isError = ref.watch(admissionsApplicationsErrorProvider);
    final isEmpty = ref.watch(admissionsApplicationsEmptyProvider);
    final applications = ref.watch(admissionsApplicationsProvider);
    final workflow = ref.watch(admissionsApplicationWorkflowProvider);
    final filterIndex = ref.watch(admissionsApplicationsFilterProvider);

    return AdmissionsModuleScaffold(
      screen: AdmissionsScreen.applications,
      filters: filterLabels,
      selectedFilterIndex: filterIndex,
      onFilterSelected: (index) => ref
          .read(admissionsApplicationsFilterProvider.notifier)
          .state = index,
      filterTrailing: FilledButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.add, size: 18),
        label: const Text('New Application'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
              child: AksharaLoadingState(
                semanticLabel: 'Loading applications',
              ),
            )
          else if (isError)
            const AksharaErrorState(message: 'Unable to load applications.')
          else ...[
            AdmissionsApplicationWorkflow(summary: workflow),
            const SizedBox(height: AksharaSpacing.s6),
            if (isEmpty || applications.isEmpty)
              const AksharaEmptyState(
                message: 'No applications match the selected filters.',
                icon: Icons.description_outlined,
                actionLabel: 'Create application',
              )
            else
              AdmissionsApplicationsTable(
                applications: applications,
                onView: (_) {},
              ),
          ],
        ],
      ),
    );
  }
}
