import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/paginated_result.dart';
import '../../../core/security/permissions.dart';
import 'package:go_router/go_router.dart';

import '../../../router/route_names.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../transport_models.dart';
import '../transport_providers.dart';
import '../widgets/transport_module_scaffold.dart';

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
    final allocations = ref.watch(transportAllocationsProvider);
    final filterIndex = ref.watch(transportAllocationFilterProvider);
    final pageResult = ref.watch(transportAllocationsPageResultProvider);

    return TransportModuleScaffold(
      screen: TransportScreen.allocation,
      filters: filterLabels,
      selectedFilterIndex: filterIndex,
      onFilterSelected: (index) =>
          ref.read(transportAllocationFilterProvider.notifier).state = index,
      filterTrailing: AksharaManageAction(
        permission: Permission.manageTransport,
        child: OutlinedButton.icon(
          onPressed: () => context.go(RouteNames.sisStudents),
          icon: const Icon(Icons.badge_outlined, size: 18),
          label: const Text('SIS registry'),
        ),
      ),
      body: _buildBody(
        context,
        isLoading: isLoading,
        isError: isError,
        isEmpty: isEmpty,
        allocations: allocations ?? const [],
        pageResult: pageResult,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
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

class _AllocationTable extends StatelessWidget {
  const _AllocationTable({required this.allocations});

  final List<StudentTransportAllocation> allocations;

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

  final StudentTransportAllocation allocation;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;

    return Semantics(
      label:
          'Student ${allocation.studentName}, ${allocation.routeName}, bus ${allocation.busNumber}',
      child: Card(
        elevation: 0,
        child: InkWell(
          onTap: () => context.go(
            RouteNames.sisStudentDetail(allocation.sisStudentId),
          ),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
