import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../router/route_names.dart';

import '../admissions_async_state.dart';
import '../admissions_models.dart';
import '../../../shared/widgets/akshara_warning_banner.dart';
import '../../../theme/spacing.dart';
import '../admissions_navigation.dart';
import '../admissions_workflow_actions.dart';
import '../widgets/admissions_module_scaffold.dart';
import 'admissions_leads_provider.dart';
import 'widgets/admissions_leads_table.dart';

/// AD-02 — Lead Management (CRM system of record).
class AdmissionsLeadsScreen extends ConsumerWidget {
  const AdmissionsLeadsScreen({super.key});

  static const List<String> filterLabels = [
    'All sources',
    'All stages',
    'All scores',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewState = ref.watch(admissionsLeadsViewStateProvider);
    final filterIndex = ref.watch(admissionsLeadsFilterProvider);

    return AdmissionsModuleScaffold(
      screen: AdmissionsScreen.leads,
      filters: filterLabels,
      selectedFilterIndex: filterIndex,
      onFilterSelected: (index) =>
          ref.read(admissionsLeadsFilterProvider.notifier).state = index,
      filterTrailing: FilledButton.icon(
        onPressed: () => showCreateLeadDialog(context, ref),
        icon: const Icon(Icons.add, size: 18),
        label: const Text('New Lead'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AksharaWarningBanner(
            message:
                'CRM system of record · Acquisition data from Marketing is read-only',
            compactMessage: true,
            horizontalPaddingOnly: true,
            semanticLabel: 'Marketing acquisition data is read-only',
          ),
          const SizedBox(height: AksharaSpacing.s4),
          AdmissionsAsyncBody<List<AdmissionsLead>>(
            state: viewState,
            loadingLabel: 'Loading leads',
            emptyMessage: 'No leads match the selected filters.',
            emptyIcon: Icons.contacts_outlined,
            emptyActionLabel: 'Add lead',
            onEmptyAction: () => showCreateLeadDialog(context, ref),
            onRetry: () =>
                retryAdmissionsFuture(ref, admissionsLeadsFutureProvider),
            builder: (leads) => AdmissionsLeadsTable(
              leads: leads,
              onView: (lead) =>
                  context.push(RouteNames.admissionsLeadDetail(lead.id)),
              onAssign: (lead) => showAssignCounselorDialog(context, ref, lead),
            ),
          ),
        ],
      ),
    );
  }
}
