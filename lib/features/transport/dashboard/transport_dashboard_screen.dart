import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/security/permissions.dart';
import '../../../router/route_names.dart';
import '../../../shared/async/erp_async_state.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../transport_models.dart';
import '../transport_providers.dart';
import '../widgets/transport_kpi_row.dart';
import '../widgets/transport_module_scaffold.dart';

/// TR-01 — Transport Dashboard.
class TransportDashboardScreen extends ConsumerWidget {
  const TransportDashboardScreen({super.key});

  static const List<String> filterLabels = [
    'AM shift',
    'PM shift',
    'All shifts',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewState = ref.watch(transportDashboardViewStateProvider);
    final filterIndex = ref.watch(transportDashboardFilterProvider);

    return TransportModuleScaffold(
      screen: TransportScreen.dashboard,
      filters: filterLabels,
      selectedFilterIndex: filterIndex,
      onFilterSelected: (index) =>
          ref.read(transportDashboardFilterProvider.notifier).state = index,
      filterTrailing: AksharaManageAction(
        permission: Permission.manageTransport,
        child: OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.download_outlined, size: 18),
          label: const Text('Export'),
        ),
      ),
      body: ErpAsyncBody<TransportDashboardData>(
        state: viewState,
        loadingLabel: 'Loading transport dashboard',
        emptyMessage: 'No transport data for the selected shift.',
        emptyIcon: Icons.directions_bus_outlined,
        onRetry: () => retryErpFuture(ref, transportDashboardFutureProvider),
        builder: (data) => _buildDashboardContent(context, data),
      ),
    );
  }

  Widget _buildDashboardContent(
    BuildContext context,
    TransportDashboardData data,
  ) {
    final isMobile = AdminLayout.isMobile(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (data.activeDelays.isNotEmpty)
          AksharaWarningBanner(
            message: data.activeDelays.first,
            actionLabel: 'View tracking',
            onAction: () => context.go(RouteNames.transportTracking),
          ),
        if (data.activeDelays.isNotEmpty)
          const SizedBox(height: AksharaSpacing.s4),
        TransportKpiRow(kpis: data.kpis, desktopColumns: 3),
        const SizedBox(height: AksharaSpacing.s6),
        const AksharaSectionHeader(title: 'Live fleet assignments'),
        const SizedBox(height: AksharaSpacing.s3),
        _FleetAssignmentsTable(assignments: data.vehicleAssignments),
        const SizedBox(height: AksharaSpacing.s6),
        if (isMobile) ...[
          _OccupancyCard(metrics: data.occupancy),
          const SizedBox(height: AksharaSpacing.s4),
          _RoutePerformanceList(items: data.routePerformance),
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _OccupancyCard(metrics: data.occupancy)),
              const SizedBox(width: AksharaSpacing.s6),
              Expanded(
                child: _RoutePerformanceList(items: data.routePerformance),
              ),
            ],
          ),
        const SizedBox(height: AksharaSpacing.s6),
        AksharaInsightCard(
          message: data.aiInsight,
          actionLabel: 'View allocation',
          icon: Icons.auto_awesome_outlined,
          semanticLabelPrefix: 'AI transport insight',
          onAction: () => context.go(RouteNames.transportAllocation),
        ),
      ],
    );
  }
}

class _FleetAssignmentsTable extends StatelessWidget {
  const _FleetAssignmentsTable({required this.assignments});

  final List<VehicleAssignment> assignments;

  @override
  Widget build(BuildContext context) {
    if (AdminLayout.isMobile(context)) {
      return Column(
        children: [
          for (final item in assignments) ...[
            _FleetAssignmentCard(assignment: item),
            const SizedBox(height: AksharaSpacing.s3),
          ],
        ],
      );
    }

    return Semantics(
      container: true,
      label: 'Fleet assignments table, ${assignments.length} buses',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Material(
          child: DataTable(
            headingRowHeight: 48,
            dataRowMinHeight: 52,
            columns: const [
              DataColumn(label: Text('Bus')),
              DataColumn(label: Text('Route')),
              DataColumn(label: Text('Driver')),
              DataColumn(label: Text('Students')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('ETA')),
            ],
            rows: [
              for (final item in assignments)
                DataRow(
                  onSelectChanged: (_) =>
                      context.go(RouteNames.transportTracking),
                  cells: [
                    DataCell(Text(item.busNumber)),
                    DataCell(Text(item.routeName)),
                    DataCell(Text(item.driverName)),
                    DataCell(Text('${item.studentCount}')),
                    DataCell(_TrackingStatusChip(status: item.trackingStatus)),
                    DataCell(Text(item.etaLabel)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FleetAssignmentCard extends StatelessWidget {
  const _FleetAssignmentCard({required this.assignment});

  final VehicleAssignment assignment;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;

    return Semantics(
      label:
          'Bus ${assignment.busNumber}, ${assignment.routeName}, ${assignment.etaLabel}',
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${assignment.busNumber} — ${assignment.routeName}',
                style: text.titleSmall,
              ),
              const SizedBox(height: AksharaSpacing.s2),
              Text('Driver: ${assignment.driverName}', style: text.bodyMedium),
              Text(
                '${assignment.studentCount} students · ${assignment.etaLabel}',
                style: text.bodySmall,
              ),
              const SizedBox(height: AksharaSpacing.s2),
              _TrackingStatusChip(status: assignment.trackingStatus),
            ],
          ),
        ),
      ),
    );
  }
}

class _OccupancyCard extends StatelessWidget {
  const _OccupancyCard({required this.metrics});

  final OccupancyMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    final colors = context.colors;

    return Semantics(
      container: true,
      label:
          'Occupancy ${metrics.utilizationPercent} percent, ${metrics.unassignedStudents} unassigned',
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AksharaSectionHeader(title: 'Fleet occupancy'),
              const SizedBox(height: AksharaSpacing.s3),
              Text(
                '${metrics.allocatedSeats} / ${metrics.totalCapacity} seats',
                style: text.headlineSmall,
              ),
              const SizedBox(height: AksharaSpacing.s2),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: metrics.utilizationPercent / 100,
                  minHeight: 10,
                  backgroundColor: colors.surfaceContainerHighest,
                  color: colors.primary,
                ),
              ),
              const SizedBox(height: AksharaSpacing.s3),
              Text(
                '${metrics.unassignedStudents} students unassigned — link to SIS registry',
                style: text.bodySmall.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoutePerformanceList extends StatelessWidget {
  const _RoutePerformanceList({required this.items});

  final List<RoutePerformance> items;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;

    return Semantics(
      container: true,
      label: 'Route performance, ${items.length} routes',
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AksharaSectionHeader(title: 'Route performance'),
              const SizedBox(height: AksharaSpacing.s3),
              for (final item in items) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(item.routeName, style: text.bodyMedium),
                    ),
                    Text(item.onTimePercent, style: text.titleSmall),
                  ],
                ),
                Text(
                  'Avg delay ${item.avgDelayMinutes} min · ${item.utilizationPercent}% utilization',
                  style: text.bodySmall,
                ),
                const SizedBox(height: AksharaSpacing.s3),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackingStatusChip extends StatelessWidget {
  const _TrackingStatusChip({required this.status});

  final TrackingStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (status) {
      TrackingStatus.moving => ('Moving', KpiAccent.success),
      TrackingStatus.idle => ('At stop', KpiAccent.primary),
      TrackingStatus.delayed => ('Delayed', KpiAccent.warning),
      TrackingStatus.offline => ('Offline', KpiAccent.error),
    };

    return AksharaStatusChip(
      label: label,
      tone: tone,
      semanticLabel: 'Tracking status: $label',
    );
  }
}
