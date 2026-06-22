import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/paginated_result.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../hostel_models.dart';
import '../hostel_providers.dart';
import '../widgets/hostel_module_scaffold.dart';

/// HO-05 — Leave Requests.
class HostelLeaveScreen extends ConsumerWidget {
  const HostelLeaveScreen({super.key});

  static const List<String> filterLabels = [
    'All',
    'Pending',
    'Approved',
    'Rejected',
    'Active passes',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(hostelLeaveLoadingProvider);
    final isError = ref.watch(hostelLeaveErrorProvider);
    final isEmpty = ref.watch(hostelLeaveEmptyProvider);
    final requests = ref.watch(hostelFilteredLeaveProvider);
    final filterIndex = ref.watch(hostelLeaveFilterProvider);
    final pageResult = ref.watch(hostelLeavePageResultProvider);

    return HostelModuleScaffold(
      screen: HostelScreen.leave,
      filters: filterLabels,
      selectedFilterIndex: filterIndex,
      onFilterSelected: (index) =>
          ref.read(hostelLeaveFilterProvider.notifier).state = index,
      body: _buildBody(
        context,
        isLoading: isLoading,
        isError: isError,
        isEmpty: isEmpty,
        requests: requests,
        pageResult: pageResult,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required bool isLoading,
    required bool isError,
    required bool isEmpty,
    required List<HostelLeaveRequest> requests,
    required PaginatedResult<HostelLeaveRequest>? pageResult,
  }) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
        child: AksharaLoadingState(
          semanticLabel: 'Loading leave requests',
        ),
      );
    }

    if (isError) {
      return const AksharaErrorState(
        message: 'Unable to load leave requests.',
      );
    }

    if (isEmpty || requests.isEmpty) {
      return const AksharaEmptyState(
        message: 'No leave requests match the selected filters.',
        icon: Icons.event_busy_outlined,
      );
    }

    final parentRoute = requests.first.parentAppRoute;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AksharaSectionHeader(title: 'Leave requests'),
        const SizedBox(height: AksharaSpacing.s3),
        _LeaveTable(requests: requests),
        AksharaPaginatedListFooter<HostelLeaveRequest>(
          result: pageResult,
          pageProvider: hostelLeavePageProvider,
        ),
        const SizedBox(height: AksharaSpacing.s6),
        AksharaInsightCard(
          message:
              'Parents submit leave via Parent App. Approved requests issue gate pass QR visible on parent dashboard.',
          actionLabel: 'Parent leave',
          icon: Icons.family_restroom_outlined,
          semanticLabelPrefix: 'Parent app integration',
          onAction: () => context.go(parentRoute),
        ),
      ],
    );
  }
}

class _LeaveTable extends StatelessWidget {
  const _LeaveTable({required this.requests});

  final List<HostelLeaveRequest> requests;

  @override
  Widget build(BuildContext context) {
    if (AdminLayout.useCardLayout(context)) {
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
      label: 'Leave requests table, ${requests.length} requests',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Material(
          child: DataTable(
            headingRowHeight: 48,
            dataRowMinHeight: 52,
            columns: const [
              DataColumn(label: Text('Student')),
              DataColumn(label: Text('Room')),
              DataColumn(label: Text('From')),
              DataColumn(label: Text('To')),
              DataColumn(label: Text('Days')),
              DataColumn(label: Text('Reason')),
              DataColumn(label: Text('Parent')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Pass')),
            ],
            rows: [
              for (final request in requests)
                DataRow(
                  cells: [
                    DataCell(Text(request.studentName)),
                    DataCell(Text(request.room)),
                    DataCell(Text(request.fromDate)),
                    DataCell(Text(request.toDate)),
                    DataCell(Text('${request.days}')),
                    DataCell(Text(request.reason)),
                    DataCell(Text(request.parentContact)),
                    DataCell(_LeaveStatusChip(status: request.status)),
                    DataCell(Text(request.gatePassId ?? '—')),
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

  final HostelLeaveRequest request;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(AksharaSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(request.studentName, style: text.titleSmall),
            Text(
              '${request.room} · ${request.fromDate} → ${request.toDate}',
              style: text.bodyMedium,
            ),
            Text(request.reason, style: text.bodySmall),
            Text(request.parentContact, style: text.bodySmall),
            const SizedBox(height: AksharaSpacing.s2),
            _LeaveStatusChip(status: request.status),
          ],
        ),
      ),
    );
  }
}

class _LeaveStatusChip extends StatelessWidget {
  const _LeaveStatusChip({required this.status});

  final HostelLeaveStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (status) {
      HostelLeaveStatus.pending => ('Pending', KpiAccent.warning),
      HostelLeaveStatus.approved => ('Approved', KpiAccent.success),
      HostelLeaveStatus.rejected => ('Rejected', KpiAccent.error),
      HostelLeaveStatus.active => ('Active pass', KpiAccent.primary),
    };

    return AksharaStatusChip(
      label: label,
      tone: tone,
      semanticLabel: 'Leave status: $label',
    );
  }
}
