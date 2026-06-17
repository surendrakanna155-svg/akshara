import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/widgets/akshara_empty_state.dart';
import '../../../shared/widgets/akshara_error_state.dart';
import '../../../shared/widgets/akshara_insight_card.dart';
import '../../../shared/widgets/akshara_loading_state.dart';
import '../../../shared/widgets/akshara_section_header.dart';
import '../../../theme/spacing.dart';
import '../../admin/admin_layout.dart';
import '../management_insight_navigation.dart';
import '../management_models.dart';
import '../widgets/management_kpi_row.dart';
import '../widgets/management_module_scaffold.dart';
import 'approval_center_provider.dart';
import 'widgets/approval_detail_panel.dart';
import 'widgets/approval_queue_table.dart';
import 'widgets/approval_type_filter.dart';

/// MG-07 / Principal Approval Center — unified cross-module inbox (M-D2).
class PrincipalApprovalCenterScreen extends ConsumerWidget {
  const PrincipalApprovalCenterScreen({super.key});

  static const statusFilterLabels = [
    'All',
    'Pending',
    'Approved',
    'Rejected',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(approvalCenterLoadingProvider);
    final isError = ref.watch(approvalCenterErrorProvider);
    final items = ref.watch(approvalCenterFilteredListProvider);
    final allItems = ref.watch(approvalCenterListProvider);
    final statusIndex = ref.watch(approvalCenterStatusFilterProvider);
    final selected = ref.watch(approvalCenterSelectedProvider);
    final kpis = ref.watch(approvalCenterKpisProvider);
    final isWide = !AdminLayout.isMobile(context);

    return ManagementModuleScaffold(
      screen: ManagementScreen.tasks,
      filters: statusFilterLabels,
      selectedFilterIndex: statusIndex,
      onFilterSelected: (index) {
        ref.read(approvalCenterStatusFilterProvider.notifier).state = index;
        ref.read(approvalCenterSelectedIdProvider.notifier).state = null;
      },
      body: Semantics(
        container: true,
        label: 'Principal approval center',
        child: KeyedSubtree(
          key: QaTestKeys.approvalCenterScreen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
                  child: AksharaLoadingState(
                    semanticLabel: 'Loading approval center',
                  ),
                )
              else if (isError)
                const AksharaErrorState(
                  message: 'Unable to load approval center.',
                )
              else if (allItems.isEmpty)
                const AksharaEmptyState(
                  message: 'No approval requests yet.',
                  icon: Icons.inbox_outlined,
                )
              else ...[
                ManagementKpiRow(kpis: kpis),
                const SizedBox(height: AksharaSpacing.s4),
                const ApprovalTypeFilter(),
                const SizedBox(height: AksharaSpacing.s4),
                const AksharaSectionHeader(title: 'Approval queue'),
                const SizedBox(height: AksharaSpacing.s3),
                if (items.isEmpty)
                  AksharaEmptyState(
                    message:
                        'No ${statusFilterLabels[statusIndex].toLowerCase()} approvals for the selected category.',
                    icon: Icons.filter_alt_outlined,
                  )
                else if (isWide)
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 3,
                          child: ApprovalQueueTable(items: items),
                        ),
                        const SizedBox(width: AksharaSpacing.s4),
                        Expanded(
                          flex: 2,
                          child: selected == null
                              ? const AksharaEmptyState(
                                  message: 'Select a request to review details.',
                                  icon: Icons.touch_app_outlined,
                                )
                              : SingleChildScrollView(
                                  child: ApprovalDetailPanel(request: selected),
                                ),
                        ),
                      ],
                    ),
                  )
                else
                  ApprovalQueueTable(items: items),
                const SizedBox(height: AksharaSpacing.s6),
                AksharaInsightCard(
                  message:
                      '${ref.watch(approvalCenterPendingCountProvider)} approvals pending review across academic, finance, leave, and inventory workflows.',
                  actionLabel: 'Review pending',
                  icon: Icons.auto_awesome_outlined,
                  semanticLabelPrefix: 'AI approval insight',
                  onAction: () {
                    ref.read(approvalCenterStatusFilterProvider.notifier).state =
                        1;
                    navigateManagementInsightAction(
                      context,
                      ManagementScreen.tasks,
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
