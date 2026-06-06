import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../router/route_names.dart';

import '../../../shared/widgets/akshara_empty_state.dart';
import '../../../shared/widgets/akshara_error_state.dart';
import '../../../shared/widgets/akshara_loading_state.dart';
import '../../../shared/widgets/akshara_warning_banner.dart';
import '../../../theme/spacing.dart';
import '../admissions_navigation.dart';
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
    final isLoading = ref.watch(admissionsLeadsLoadingProvider);
    final isError = ref.watch(admissionsLeadsErrorProvider);
    final isEmpty = ref.watch(admissionsLeadsEmptyProvider);
    final leads = ref.watch(admissionsLeadsProvider);
    final filterIndex = ref.watch(admissionsLeadsFilterProvider);

    return AdmissionsModuleScaffold(
      screen: AdmissionsScreen.leads,
      filters: filterLabels,
      selectedFilterIndex: filterIndex,
      onFilterSelected: (index) =>
          ref.read(admissionsLeadsFilterProvider.notifier).state = index,
      filterTrailing: FilledButton.icon(
        onPressed: () {},
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
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
              child: AksharaLoadingState(semanticLabel: 'Loading leads'),
            )
          else if (isError)
            const AksharaErrorState(message: 'Unable to load leads.')
          else if (isEmpty || leads.isEmpty)
            const AksharaEmptyState(
              message: 'No leads match the selected filters.',
              icon: Icons.contacts_outlined,
              actionLabel: 'Add lead',
            )
          else
            AdmissionsLeadsTable(
              leads: leads,
              onView: (lead) =>
                  context.push(RouteNames.admissionsLeadDetail(lead.id)),
              onAssign: (_) {},
            ),
        ],
      ),
    );
  }
}
