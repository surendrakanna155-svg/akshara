import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/akshara_empty_state.dart';
import '../../../shared/widgets/akshara_error_state.dart';
import '../../../shared/widgets/akshara_insight_card.dart';
import '../../../shared/widgets/akshara_loading_state.dart';
import '../../../shared/widgets/akshara_section_header.dart';
import '../../../shared/widgets/akshara_status_chip.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../hr_models.dart';
import '../hr_providers.dart';
import '../widgets/hr_module_scaffold.dart';
import '../widgets/hr_segment_panel.dart';

/// HR-05 — Leave Management.
class HrLeaveScreen extends ConsumerWidget {
  const HrLeaveScreen({super.key});

  static const List<String> filterLabels = [
    'All',
    'Pending',
    'Approved',
    'Rejected',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(hrLeaveLoadingProvider);
    final isError = ref.watch(hrLeaveErrorProvider);
    final isEmpty = ref.watch(hrLeaveEmptyProvider);
    final data = ref.watch(hrLeaveProvider);
    final requests = ref.watch(hrFilteredLeaveProvider);
    final filterIndex = ref.watch(hrLeaveFilterProvider);

    return HrModuleScaffold(
      screen: HrScreen.leave,
      filters: filterLabels,
      selectedFilterIndex: filterIndex,
      onFilterSelected: (index) =>
          ref.read(hrLeaveFilterProvider.notifier).state = index,
      body: _buildBody(
        context,
        isLoading: isLoading,
        isError: isError,
        isEmpty: isEmpty,
        data: data,
        requests: requests,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required bool isLoading,
    required bool isError,
    required bool isEmpty,
    required HrLeaveData? data,
    required List<HrLeaveRequest> requests,
  }) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
        child: AksharaLoadingState(semanticLabel: 'Loading leave requests'),
      );
    }

    if (isError) {
      return const AksharaErrorState(message: 'Unable to load leave data.');
    }

    if (isEmpty || data == null || requests.isEmpty) {
      return const AksharaEmptyState(
        message: 'No leave requests match the selected filters.',
        icon: Icons.event_busy_outlined,
      );
    }

    final isMobile = AdminLayout.isMobile(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AksharaSectionHeader(title: 'Leave requests'),
        Text(
          '${data.pendingCount} pending approval',
          style: context.aksharaText.bodySmall,
        ),
        const SizedBox(height: AksharaSpacing.s3),
        _LeaveTable(requests: requests),
        const SizedBox(height: AksharaSpacing.s6),
        if (!isMobile)
          HrSegmentPanel(
            title: 'Leave by type',
            segments: data.leaveByType,
            height: 280,
          )
        else
          HrSegmentPanel(
            title: 'Leave by type',
            segments: data.leaveByType,
            height: 240,
          ),
        const SizedBox(height: AksharaSpacing.s6),
        AksharaInsightCard(
          message: data.integrationNote,
          actionLabel: 'View settings',
          icon: Icons.approval_outlined,
          semanticLabelPrefix: 'Leave workflow integration',
          onAction: () {},
        ),
      ],
    );
  }
}

class _LeaveTable extends StatelessWidget {
  const _LeaveTable({required this.requests});

  final List<HrLeaveRequest> requests;

  @override
  Widget build(BuildContext context) {
    if (AdminLayout.isMobile(context)) {
      return Column(
        children: [
          for (final request in requests) ...[
            _LeaveCard(request: request),
            const SizedBox(height: AksharaSpacing.s3),
          ],
        ],
      );
    }

    return Semantics(
      container: true,
      label: 'Leave requests table, ${requests.length} items',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Material(
          child: DataTable(
            headingRowHeight: 48,
            dataRowMinHeight: 56,
            columns: const [
              DataColumn(label: Text('Employee')),
              DataColumn(label: Text('Type')),
              DataColumn(label: Text('From')),
              DataColumn(label: Text('To')),
              DataColumn(label: Text('Days')),
              DataColumn(label: Text('Approver')),
              DataColumn(label: Text('Status')),
            ],
            rows: [
              for (final request in requests)
                DataRow(
                  onSelectChanged: (_) {},
                  cells: [
                    DataCell(Text(request.employeeName)),
                    DataCell(Text(request.leaveType.name)),
                    DataCell(Text(request.fromDate)),
                    DataCell(Text(request.toDate)),
                    DataCell(Text('${request.days}')),
                    DataCell(Text(request.approver)),
                    DataCell(_LeaveStatusChip(status: request.status)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeaveCard extends StatelessWidget {
  const _LeaveCard({required this.request});

  final HrLeaveRequest request;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;

    return Semantics(
      label: 'Leave request ${request.employeeName}, ${request.days} days',
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(request.employeeName, style: text.titleSmall),
                  ),
                  _LeaveStatusChip(status: request.status),
                ],
              ),
              Text(
                '${request.leaveType.name} · ${request.fromDate} – ${request.toDate}',
                style: text.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeaveStatusChip extends StatelessWidget {
  const _LeaveStatusChip({required this.status});

  final HrLeaveStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (status) {
      HrLeaveStatus.pending => ('Pending', KpiAccent.warning),
      HrLeaveStatus.approved => ('Approved', KpiAccent.success),
      HrLeaveStatus.rejected => ('Rejected', KpiAccent.error),
      HrLeaveStatus.cancelled => ('Cancelled', KpiAccent.neutral),
    };

    return AksharaStatusChip(label: label, tone: tone);
  }
}
