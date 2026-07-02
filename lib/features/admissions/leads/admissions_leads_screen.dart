import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/testing/qa_test_keys.dart';
import '../../../core/repositories/paginated_result.dart';
import '../../../router/route_names.dart';

import '../admissions_async_state.dart';
import '../admissions_models.dart';
import '../../../core/security/permissions.dart';
import '../../../core/security/rbac_service.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../admissions_navigation.dart';
import '../admissions_workflow_actions.dart';
import '../widgets/admissions_module_scaffold.dart';
import 'admissions_leads_provider.dart';
import 'widgets/admissions_bulk_action_bar.dart';
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
    final pageResult = ref.watch(admissionsLeadsPageResultProvider);
    final filterIndex = ref.watch(admissionsLeadsFilterProvider);
    final selectedLeadIds = ref.watch(admissionsSelectedLeadsProvider);
    // ADM-3: bulk mutations are manage-grade; selection is only offered when the
    // operator can act on it.
    final canManage = ref.watch(canManageAdmissionsProvider);

    // Drop any selected ids that are no longer on the current page (e.g. after a
    // reload/pagination) so the bulk bar never acts on a stale selection.
    ref.listen<PaginatedResult<AdmissionsLead>?>(
      admissionsLeadsPageResultProvider,
      (previous, next) {
        if (next == null) return;
        final visible = next.items.map((lead) => lead.id).toSet();
        final current = ref.read(admissionsSelectedLeadsProvider);
        final pruned = current.intersection(visible);
        if (pruned.length != current.length) {
          ref.read(admissionsSelectedLeadsProvider.notifier).state = pruned;
        }
      },
    );

    return AdmissionsModuleScaffold(
      screen: AdmissionsScreen.leads,
      filters: filterLabels,
      selectedFilterIndex: filterIndex,
      onFilterSelected: (index) =>
          ref.read(admissionsLeadsFilterProvider.notifier).state = index,
      filterTrailing: AksharaManageAction(
        permission: Permission.manageAdmissions,
        child: FilledButton.icon(
          key: QaTestKeys.admissionsCreateLeadButton,
          onPressed: () => showCreateLeadDialog(context, ref),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('New Lead'),
        ),
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
          AdmissionsAsyncBody<PaginatedResult<AdmissionsLead>>(
            state: viewState,
            loadingLabel: 'Loading leads',
            emptyMessage: 'No leads match the selected filters.',
            emptyIcon: Icons.contacts_outlined,
            emptyActionLabel: 'Add lead',
            onEmptyAction: () => showCreateLeadDialog(context, ref),
            onRetry: () =>
                retryAdmissionsFuture(ref, admissionsLeadsFutureProvider),
            builder: (result) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (canManage && selectedLeadIds.isNotEmpty)
                  AdmissionsBulkActionBar(
                    selectedCount: selectedLeadIds.length,
                    onAssign: () => showBulkAssignDialog(
                      context,
                      ref,
                      selectedLeadIds.toList(),
                    ),
                    onChangeStage: () => showBulkStageDialog(
                      context,
                      ref,
                      selectedLeadIds.toList(),
                    ),
                    onClear: () => ref
                        .read(admissionsSelectedLeadsProvider.notifier)
                        .state = <String>{},
                  ),
                AdmissionsLeadsTable(
                  leads: result.items,
                  selectedLeadIds: selectedLeadIds,
                  onSelectChanged: canManage
                      ? (lead, selected) {
                          final next = {...selectedLeadIds};
                          if (selected) {
                            next.add(lead.id);
                          } else {
                            next.remove(lead.id);
                          }
                          ref
                              .read(admissionsSelectedLeadsProvider.notifier)
                              .state = next;
                        }
                      : null,
                  onView: (lead) =>
                      context.push(RouteNames.admissionsLeadDetail(lead.id)),
                  onAssign: (lead) =>
                      showAssignCounselorDialog(context, ref, lead),
                ),
                if (pageResult != null)
                  AksharaPaginationBar<AdmissionsLead>(
                    result: pageResult,
                    onPageChanged: (page) => ref
                        .read(admissionsLeadsPageProvider.notifier)
                        .state = page,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
