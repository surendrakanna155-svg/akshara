import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../router/route_names.dart';
import '../../../shared/widgets/akshara_empty_state.dart';
import '../../../shared/widgets/akshara_error_state.dart';
import '../../../shared/widgets/akshara_insight_card.dart';
import '../../../shared/widgets/akshara_loading_state.dart';
import '../../../shared/widgets/akshara_section_header.dart';
import '../../../shared/widgets/akshara_status_chip.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../inventory_models.dart';
import '../inventory_providers.dart';
import '../widgets/inventory_module_scaffold.dart';

/// INV-04 — Allocation (Finance, HR, Hostel, Library integrations).
class InventoryAllocationScreen extends ConsumerWidget {
  const InventoryAllocationScreen({super.key});

  static const List<String> filterLabels = [
    'All',
    'Active',
    'Pending return',
    'Overdue',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(inventoryAllocationLoadingProvider);
    final isError = ref.watch(inventoryAllocationErrorProvider);
    final isEmpty = ref.watch(inventoryAllocationEmptyProvider);
    final allocations = ref.watch(inventoryFilteredAllocationsProvider);
    final filterIndex = ref.watch(inventoryAllocationFilterProvider);

    return InventoryModuleScaffold(
      screen: InventoryScreen.allocation,
      filters: filterLabels,
      selectedFilterIndex: filterIndex,
      onFilterSelected: (index) =>
          ref.read(inventoryAllocationFilterProvider.notifier).state = index,
      filterTrailing: OutlinedButton.icon(
        onPressed: () => context.go(RouteNames.hrEmployees),
        icon: const Icon(Icons.groups_outlined, size: 18),
        label: const Text('HR directory'),
      ),
      body: _buildBody(
        context,
        isLoading: isLoading,
        isError: isError,
        isEmpty: isEmpty,
        allocations: allocations,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required bool isLoading,
    required bool isError,
    required bool isEmpty,
    required List<InventoryAllocation> allocations,
  }) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
        child: AksharaLoadingState(
          semanticLabel: 'Loading asset allocations',
        ),
      );
    }

    if (isError) {
      return const AksharaErrorState(
        message: 'Unable to load asset allocations.',
      );
    }

    if (isEmpty || allocations.isEmpty) {
      return const AksharaEmptyState(
        message: 'No asset allocations found.',
        icon: Icons.assignment_outlined,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AksharaSectionHeader(title: 'Asset allocation'),
        const SizedBox(height: AksharaSpacing.s3),
        _AllocationTable(allocations: allocations),
        const SizedBox(height: AksharaSpacing.s6),
        AksharaInsightCard(
          message:
              'Allocations link to HR employees (HR-EMP-*), Hostel blocks, and Library sections. Finance tracks asset values via FN-AST-* IDs.',
          actionLabel: 'Open Hostel',
          icon: Icons.link_outlined,
          semanticLabelPrefix: 'Cross-module integration',
          onAction: () => context.go(RouteNames.hostelDashboard),
        ),
      ],
    );
  }
}

class _AllocationTable extends StatelessWidget {
  const _AllocationTable({required this.allocations});

  final List<InventoryAllocation> allocations;

  @override
  Widget build(BuildContext context) {
    if (AdminLayout.isMobile(context)) {
      return Column(
        children: [
          for (final alloc in allocations) ...[
            _AllocationCard(allocation: alloc),
            const SizedBox(height: AksharaSpacing.s3),
          ],
        ],
      );
    }

    return Semantics(
      container: true,
      label: 'Asset allocation, ${allocations.length} records',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Material(
          child: DataTable(
            headingRowHeight: 48,
            dataRowMinHeight: 52,
            columns: const [
              DataColumn(label: Text('Asset')),
              DataColumn(label: Text('Department')),
              DataColumn(label: Text('Assigned to')),
              DataColumn(label: Text('HR ID')),
              DataColumn(label: Text('Hostel')),
              DataColumn(label: Text('Library')),
              DataColumn(label: Text('Status')),
            ],
            rows: [
              for (final alloc in allocations)
                DataRow(
                  cells: [
                    DataCell(Text(alloc.assetName)),
                    DataCell(Text(alloc.department)),
                    DataCell(Text(alloc.assignedTo)),
                    DataCell(Text(alloc.hrEmployeeId ?? '—')),
                    DataCell(Text(alloc.hostelBlock ?? '—')),
                    DataCell(Text(alloc.librarySection ?? '—')),
                    DataCell(_AllocationStatusChip(status: alloc.status)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AllocationCard extends StatelessWidget {
  const _AllocationCard({required this.allocation});

  final InventoryAllocation allocation;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;

    return Semantics(
      label: 'Allocation ${allocation.assetTag}, ${allocation.department}',
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(allocation.assetName, style: text.titleSmall),
              const SizedBox(height: AksharaSpacing.s2),
              Text(
                '${allocation.department} · ${allocation.assignedTo}',
                style: text.bodyMedium,
              ),
              Text(allocation.integrationNote, style: text.bodySmall),
              const SizedBox(height: AksharaSpacing.s2),
              _AllocationStatusChip(status: allocation.status),
            ],
          ),
        ),
      ),
    );
  }
}

class _AllocationStatusChip extends StatelessWidget {
  const _AllocationStatusChip({required this.status});

  final InventoryAllocationStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (status) {
      InventoryAllocationStatus.active => ('Active', KpiAccent.success),
      InventoryAllocationStatus.pendingReturn => ('Pending return', KpiAccent.warning),
      InventoryAllocationStatus.overdue => ('Overdue', KpiAccent.error),
    };

    return AksharaStatusChip(
      label: label,
      tone: tone,
      semanticLabel: 'Allocation status: $label',
    );
  }
}
