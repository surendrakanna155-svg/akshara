import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/spacing.dart';
import '../admissions_async_state.dart';
import '../admissions_models.dart';
import '../admissions_mutations_provider.dart';
import '../admissions_navigation.dart';
import '../admissions_requests.dart';
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
    final viewState = ref.watch(admissionsApplicationsViewStateProvider);
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
        onPressed: () => _createApplication(context, ref),
        icon: const Icon(Icons.add, size: 18),
        label: const Text('New Application'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdmissionsAsyncBody<List<AdmissionsApplication>>(
            state: viewState,
            loadingLabel: 'Loading applications',
            emptyMessage: 'No applications match the selected filters.',
            emptyIcon: Icons.description_outlined,
            emptyActionLabel: 'Create application',
            onRetry: () => retryAdmissionsFuture(
              ref,
              admissionsApplicationsFutureProvider,
            ),
            builder: (applications) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AdmissionsApplicationWorkflow(summary: workflow),
                const SizedBox(height: AksharaSpacing.s6),
                AdmissionsApplicationsTable(
                  applications: applications,
                  onView: (app) => _handleApplicationAction(context, ref, app),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createApplication(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(createApplicationProvider.notifier).execute(
            const CreateApplicationRequest(
              studentName: 'New Student',
              classLabel: '5',
              parentName: 'New Parent',
            ),
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Draft application created')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }

  Future<void> _handleApplicationAction(
    BuildContext context,
    WidgetRef ref,
    AdmissionsApplication app,
  ) async {
    if (app.status == ApplicationStatus.draft) {
      try {
        await ref.read(submitApplicationProvider.notifier).execute(app.id);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Application submitted')),
        );
      } catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error')),
        );
      }
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Application ${app.id} · ${app.status.label}')),
    );
  }
}
