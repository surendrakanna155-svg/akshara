import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/paginated_result.dart';
import '../../../core/security/permissions.dart';
import '../../../core/testing/qa_test_keys.dart';
import 'package:go_router/go_router.dart';

import '../../../router/route_names.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../transport_models.dart';
import '../transport_providers.dart';
import '../transport_workflow_actions.dart';
import '../widgets/transport_module_scaffold.dart';
import 'transport_bulk_allocation_sheet.dart';

/// TR-05 — Student Allocation (SIS-linked).
class TransportAllocationScreen extends ConsumerWidget {
  const TransportAllocationScreen({super.key});

  static const List<String> filterLabels = [
    'All routes',
    'Route 12',
    'Route 08',
    'Unassigned',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(transportAllocationLoadingProvider);
    final isError = ref.watch(transportAllocationErrorProvider);
    final isEmpty = ref.watch(transportAllocationEmptyProvider);
    final allocations = ref.watch(transportFilteredAllocationsProvider);
    final filterIndex = ref.watch(transportAllocationFilterProvider);
    final pageResult = ref.watch(transportAllocationsPageResultProvider);
    // Ensure routes are loaded before the bulk-allocate sheet reads them.
    final routes = ref.watch(transportRoutesProvider);

    return TransportModuleScaffold(
      screen: TransportScreen.allocation,
      filters: filterLabels,
      selectedFilterIndex: filterIndex,
      onFilterSelected: (index) =>
          ref.read(transportAllocationFilterProvider.notifier).state = index,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: AksharaManageAction(
              permission: Permission.manageTransport,
              child: Wrap(
                spacing: AksharaSpacing.s2,
                children: [
                  FilledButton.icon(
                    key: QaTestKeys.transportBulkAllocateButton,
                    onPressed: () => showBulkAllocationSheet(
                      context,
                      ref,
                      routes: routes,
                    ),
                    icon: const Icon(Icons.groups_outlined, size: 18),
                    label: const Text('Bulk allocate'),
                  ),
                  OutlinedButton.icon(
                    key: QaTestKeys.transportRaiseDemandButton,
                    onPressed: () =>
                        showRaiseDemandForUnbilledDialog(context, ref),
                    icon: const Icon(Icons.request_quote_outlined, size: 18),
                    label: const Text('Raise demand (unbilled)'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.go(RouteNames.sisStudents),
                    icon: const Icon(Icons.badge_outlined, size: 18),
                    label: const Text('SIS registry'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AksharaSpacing.s4),
          _buildBody(
            context,
            ref,
            isLoading: isLoading,
            isError: isError,
            isEmpty: isEmpty,
            allocations: allocations,
            pageResult: pageResult,
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref, {
    required bool isLoading,
    required bool isError,
    required bool isEmpty,
    required List<StudentTransportAllocation> allocations,
    required PaginatedResult<StudentTransportAllocation>? pageResult,
  }) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
        child: AksharaLoadingState(
          semanticLabel: 'Loading student allocations',
        ),
      );
    }

    if (isError) {
      return const AksharaErrorState(
        message: 'Unable to load student allocations.',
      );
    }

    if (isEmpty || allocations.isEmpty) {
      return const AksharaEmptyState(
        message: 'No student transport allocations found.',
        icon: Icons.group_add_outlined,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AksharaSectionHeader(title: 'Student transport allocation'),
        const SizedBox(height: AksharaSpacing.s3),
        _AllocationTable(allocations: allocations),
        AksharaPaginatedListFooter<StudentTransportAllocation>(
          result: pageResult,
          pageProvider: transportAllocationsPageProvider,
        ),
        const SizedBox(height: AksharaSpacing.s6),
        AksharaInsightCard(
          message:
              'Allocations reference SIS student IDs. Parent App shows route and bus assignment for each linked student.',
          actionLabel: 'Open SIS',
          icon: Icons.link_outlined,
          semanticLabelPrefix: 'SIS integration',
          onAction: () => context.go(RouteNames.sisStudents),
        ),
      ],
    );
  }
}

class _AllocationTable extends ConsumerWidget {
  const _AllocationTable({required this.allocations});

  final List<StudentTransportAllocation> allocations;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (AdminLayout.useCardLayout(context)) {
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
      label: 'Student allocations table, ${allocations.length} students',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Material(
          child: DataTable(
            headingRowHeight: 48,
            dataRowMinHeight: 56,
            columns: const [
              DataColumn(label: Text('Student')),
              DataColumn(label: Text('Class')),
              DataColumn(label: Text('Pickup')),
              DataColumn(label: Text('Drop')),
              DataColumn(label: Text('Route')),
              DataColumn(label: Text('Bus')),
              DataColumn(label: Text('SIS ID')),
              DataColumn(label: Text('Billed')),
              DataColumn(label: Text('Actions')),
            ],
            rows: [
              for (final alloc in allocations)
                DataRow(
                  onSelectChanged: (_) =>
                      context.go(RouteNames.sisStudentDetail(alloc.sisStudentId)),
                  cells: [
                    DataCell(Text(alloc.studentName)),
                    DataCell(Text(alloc.classLabel)),
                    DataCell(Text(alloc.pickupStop)),
                    DataCell(Text(alloc.dropStop)),
                    DataCell(Text(alloc.routeName)),
                    DataCell(Text(alloc.busNumber)),
                    DataCell(Text(alloc.sisStudentId)),
                    DataCell(_BilledStatus(allocation: alloc)),
                    DataCell(_AllocationActions(allocation: alloc)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AllocationCard extends ConsumerWidget {
  const _AllocationCard({required this.allocation});

  final StudentTransportAllocation allocation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = context.aksharaText;

    return Semantics(
      label:
          'Student ${allocation.studentName}, ${allocation.routeName}, bus ${allocation.busNumber}',
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(allocation.studentName, style: text.titleSmall),
              Text('Class ${allocation.classLabel}', style: text.bodySmall),
              Text(
                '${allocation.pickupStop} → ${allocation.dropStop}',
                style: text.bodySmall,
              ),
              Text(
                '${allocation.routeName} · ${allocation.busNumber}',
                style: text.bodySmall,
              ),
              if (allocation.isAssigned) ...[
                const SizedBox(height: AksharaSpacing.s2),
                _BilledStatus(allocation: allocation),
              ],
              const SizedBox(height: AksharaSpacing.s3),
              _AllocationActions(allocation: allocation),
            ],
          ),
        ),
      ),
    );
  }
}

/// PRA-P0-20 — per-row transport-fee billed status. Assigned students show
/// Billed / Unbilled (derived `demandRaised`); unassigned rows show a dash.
class _BilledStatus extends StatelessWidget {
  const _BilledStatus({required this.allocation});

  final StudentTransportAllocation allocation;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    if (!allocation.isAssigned) {
      return Text('—', style: text.bodySmall);
    }
    final billed = allocation.demandRaised;
    final scheme = Theme.of(context).colorScheme;
    final color = billed ? scheme.primary : scheme.outline;
    return Semantics(
      label: billed ? 'Transport fee billed' : 'Transport fee not billed',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            billed ? Icons.check_circle_outline : Icons.pending_outlined,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(billed ? 'Billed' : 'Unbilled', style: text.bodySmall),
        ],
      ),
    );
  }
}

class _AllocationActions extends ConsumerWidget {
  const _AllocationActions({required this.allocation});

  final StudentTransportAllocation allocation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch routes so they are loaded before the assign dialog reads them.
    final routes = ref.watch(transportRoutesProvider);
    return AksharaManageAction(
      permission: Permission.manageTransport,
      child: Wrap(
        spacing: AksharaSpacing.s2,
        runSpacing: AksharaSpacing.s2,
        children: [
          if (!allocation.isAssigned)
            FilledButton(
              key: QaTestKeys.transportAssignStudentButton(allocation.id),
              onPressed: () => showAssignStudentTransportDialog(
                context,
                ref,
                allocation: allocation,
                routes: routes,
              ),
              style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
              child: const Text('Assign'),
            ),
          if (allocation.isAssigned) ...[
            OutlinedButton(
              key: QaTestKeys.transportTransferStudentButton(allocation.id),
              onPressed: () => showTransferStudentTransportDialog(
                context,
                ref,
                allocation: allocation,
                routes: routes,
              ),
              style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
              child: const Text('Transfer'),
            ),
            OutlinedButton(
              key: QaTestKeys.transportRemoveStudentButton(allocation.id),
              onPressed: () => removeStudentFromRoute(context, ref, allocation),
              style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
              child: const Text('Remove'),
            ),
          ],
        ],
      ),
    );
  }
}
