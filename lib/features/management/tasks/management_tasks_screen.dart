import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/akshara_empty_state.dart';
import '../../../shared/widgets/akshara_error_state.dart';
import '../../../shared/widgets/akshara_insight_card.dart';
import '../../../shared/widgets/akshara_loading_state.dart';
import '../../../shared/widgets/akshara_section_header.dart';
import '../../../shared/widgets/akshara_status_chip.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../management_insight_navigation.dart';
import '../management_models.dart';
import '../management_providers.dart';
import '../management_workflow_actions.dart';
import '../widgets/management_kpi_row.dart';
import '../widgets/management_module_scaffold.dart';

/// MG-07 — Tasks & Approvals.
class ManagementTasksScreen extends ConsumerWidget {
  const ManagementTasksScreen({super.key});

  static const List<String> filterLabels = [
    'All',
    'Pending',
    'Approved',
    'Rejected',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(managementTasksLoadingProvider);
    final isError = ref.watch(managementTasksErrorProvider);
    final isEmpty = ref.watch(managementTasksEmptyProvider);
    final data = ref.watch(managementTasksProvider);
    final approvals = ref.watch(managementFilteredApprovalsProvider);
    final filterIndex = ref.watch(managementTasksFilterProvider);

    return ManagementModuleScaffold(
      screen: ManagementScreen.tasks,
      filters: filterLabels,
      selectedFilterIndex: filterIndex,
      onFilterSelected: (index) =>
          ref.read(managementTasksFilterProvider.notifier).state = index,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
              child: AksharaLoadingState(
                semanticLabel: 'Loading tasks and approvals',
              ),
            )
          else if (isError)
            const AksharaErrorState(
              message: 'Unable to load tasks and approvals.',
            )
          else if (isEmpty || data == null)
            const AksharaEmptyState(
              message: 'No approval tasks for the selected filters.',
              icon: Icons.task_alt_outlined,
            )
          else ...[
            ManagementKpiRow(kpis: data.kpis),
            const SizedBox(height: AksharaSpacing.s6),
            const AksharaSectionHeader(title: 'Approval queue'),
            const SizedBox(height: AksharaSpacing.s3),
            if (approvals.isEmpty)
              AksharaEmptyState(
                message: 'No ${filterLabels[filterIndex].toLowerCase()} approvals.',
                icon: Icons.inbox_outlined,
              )
            else
              _ApprovalsSection(approvals: approvals),
            const SizedBox(height: AksharaSpacing.s6),
            AksharaInsightCard(
              message: data.aiInsight,
              actionLabel: 'Review pending',
              icon: Icons.auto_awesome_outlined,
              semanticLabelPrefix: 'AI approval insight',
              onAction: () => navigateManagementInsightAction(
                context,
                ManagementScreen.tasks,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ApprovalsSection extends StatelessWidget {
  const _ApprovalsSection({required this.approvals});

  final List<ManagementApprovalItem> approvals;

  @override
  Widget build(BuildContext context) {
    if (AdminLayout.isMobile(context)) {
      return Column(
        children: [
          for (final approval in approvals) ...[
            _ApprovalMobileCard(approval: approval),
            const SizedBox(height: AksharaSpacing.s3),
          ],
        ],
      );
    }

    return Semantics(
      container: true,
      label: 'Approval queue table, ${approvals.length} items',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Material(
          child: DataTable(
            headingRowHeight: 48,
            dataRowMinHeight: 64,
            dataRowMaxHeight: 80,
            columns: const [
              DataColumn(label: Text('Title')),
              DataColumn(label: Text('Type')),
              DataColumn(label: Text('Requester')),
              DataColumn(label: Text('Amount')),
              DataColumn(label: Text('Date')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('AI')),
              DataColumn(label: Text('Actions')),
            ],
            rows: [
              for (final approval in approvals)
                DataRow(
                  onSelectChanged: (_) =>
                      context.go(approval.sourceModuleRoute),
                  cells: [
                    DataCell(Text(approval.title)),
                    DataCell(Text(_typeLabel(approval.type))),
                    DataCell(Text(approval.requester)),
                    DataCell(Text(approval.amount)),
                    DataCell(Text(approval.dateLabel)),
                    DataCell(_ApprovalStatusChip(status: approval.status)),
                    DataCell(
                      _AiRecommendationChip(
                        recommendation: approval.aiRecommendation,
                      ),
                    ),
                    DataCell(_ApprovalActions(approval: approval)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _typeLabel(ManagementApprovalType type) => switch (type) {
        ManagementApprovalType.budget => 'Budget',
        ManagementApprovalType.expense => 'Expense',
        ManagementApprovalType.payroll => 'Payroll',
        ManagementApprovalType.vendor => 'Vendor',
        ManagementApprovalType.marketing => 'Marketing',
        ManagementApprovalType.admission => 'Admission',
      };
}

class _ApprovalMobileCard extends StatelessWidget {
  const _ApprovalMobileCard({required this.approval});

  final ManagementApprovalItem approval;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;

    return Semantics(
      label: 'Approval: ${approval.title}, ${approval.amount}',
      child: Card(
        elevation: 0,
        child: InkWell(
          onTap: () => context.go(approval.sourceModuleRoute),
          child: Padding(
            padding: const EdgeInsets.all(AksharaSpacing.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(approval.title, style: text.titleSmall),
                const SizedBox(height: AksharaSpacing.s2),
                Text(
                  '${approval.requester} · ${approval.amount} · ${approval.dateLabel}',
                  style: text.bodySmall,
                ),
                const SizedBox(height: AksharaSpacing.s3),
                Wrap(
                  spacing: AksharaSpacing.s2,
                  runSpacing: AksharaSpacing.s2,
                  children: [
                    _ApprovalStatusChip(status: approval.status),
                    _AiRecommendationChip(
                      recommendation: approval.aiRecommendation,
                    ),
                  ],
                ),
                if (approval.status == ManagementApprovalStatus.pending) ...[
                  const SizedBox(height: AksharaSpacing.s3),
                  _ApprovalActions(approval: approval),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ApprovalStatusChip extends StatelessWidget {
  const _ApprovalStatusChip({required this.status});

  final ManagementApprovalStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (status) {
      ManagementApprovalStatus.pending => ('Pending', KpiAccent.warning),
      ManagementApprovalStatus.approved => ('Approved', KpiAccent.success),
      ManagementApprovalStatus.rejected => ('Rejected', KpiAccent.error),
    };
    return AksharaStatusChip(label: label, tone: tone);
  }
}

class _AiRecommendationChip extends StatelessWidget {
  const _AiRecommendationChip({required this.recommendation});

  final ManagementAiRecommendation recommendation;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (recommendation) {
      ManagementAiRecommendation.approve => ('AI: Approve', KpiAccent.success),
      ManagementAiRecommendation.review => ('AI: Review', KpiAccent.warning),
      ManagementAiRecommendation.reject => ('AI: Reject', KpiAccent.error),
    };
    return Semantics(
      label: 'AI recommendation: $label',
      child: AksharaStatusChip(label: label, tone: tone),
    );
  }
}

class _ApprovalActions extends ConsumerWidget {
  const _ApprovalActions({required this.approval});

  final ManagementApprovalItem approval;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (approval.status != ManagementApprovalStatus.pending) {
      return const SizedBox.shrink();
    }

    return Semantics(
      label: 'Approval actions for ${approval.title}',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton(
            key: QaTestKeys.managementApproveButton(approval.id),
            onPressed: () => approveManagementItem(context, ref, approval),
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('Approve'),
          ),
          const SizedBox(width: AksharaSpacing.s2),
          OutlinedButton(
            key: QaTestKeys.managementRejectButton(approval.id),
            onPressed: () => rejectManagementItem(context, ref, approval),
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }
}
