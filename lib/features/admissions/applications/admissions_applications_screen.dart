import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/paginated_result.dart';
import '../../../core/security/permissions.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/widgets/widgets.dart';
import '../admissions_journey_context_provider.dart';
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
import '../../../core/errors/error_text.dart';

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
    final pageResult = ref.watch(admissionsApplicationsPageResultProvider);
    final workflow = ref.watch(admissionsApplicationWorkflowProvider);
    final filterIndex = ref.watch(admissionsApplicationsFilterProvider);

    return AdmissionsModuleScaffold(
      screen: AdmissionsScreen.applications,
      filters: filterLabels,
      selectedFilterIndex: filterIndex,
      onFilterSelected: (index) => ref
          .read(admissionsApplicationsFilterProvider.notifier)
          .state = index,
      filterTrailing: AksharaManageAction(
        permission: Permission.manageAdmissions,
        child: FilledButton.icon(
          key: QaTestKeys.admissionsCreateApplicationButton,
          onPressed: () => _createApplication(context, ref),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('New Application'),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdmissionsAsyncBody<PaginatedResult<AdmissionsApplication>>(
            state: viewState,
            loadingLabel: 'Loading applications',
            emptyMessage: 'No applications match the selected filters.',
            emptyIcon: Icons.description_outlined,
            emptyActionLabel: 'Create application',
            onRetry: () => retryAdmissionsFuture(
              ref,
              admissionsApplicationsFutureProvider,
            ),
            builder: (result) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AdmissionsApplicationWorkflow(summary: workflow),
                const SizedBox(height: AksharaSpacing.s6),
                AdmissionsApplicationsTable(
                  applications: result.items,
                  onView: (app) => _handleApplicationAction(context, ref, app),
                ),
                if (pageResult != null)
                  AksharaPaginationBar<AdmissionsApplication>(
                    result: pageResult,
                    onPageChanged: (page) => ref
                        .read(admissionsApplicationsPageProvider.notifier)
                        .state = page,
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
      final lastLead = ref.read(admissionsLastCreatedLeadProvider);
      final app = await ref.read(createApplicationProvider.notifier).execute(
            CreateApplicationRequest(
              studentName: lastLead?.studentName ?? 'New Student',
              classLabel: lastLead?.classLabel ?? '5',
              parentName: lastLead?.parentName ?? 'New Parent',
              leadId: lastLead?.id,
              counselor: lastLead?.counselor ?? '',
            ),
          );
      if (app != null) {
        ref.read(admissionsActiveApplicationIdProvider.notifier).state = app.id;
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Draft application created (${app?.id ?? ''})'),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(aksharaErrorMessage(error))),
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
        ref.read(admissionsActiveApplicationIdProvider.notifier).state = app.id;
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            key: QaTestKeys.admissionsApplicationSubmittedSnackbar,
            content: Text('Application submitted (${app.id})'),
          ),
        );
      } catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(aksharaErrorMessage(error))),
        );
      }
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Application ${app.id} · ${app.status.label}')),
    );
  }
}
