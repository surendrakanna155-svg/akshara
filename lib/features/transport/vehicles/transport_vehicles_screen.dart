import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/akshara_empty_state.dart';
import '../../../shared/widgets/akshara_error_state.dart';
import '../../../shared/widgets/akshara_loading_state.dart';
import '../../../shared/widgets/akshara_section_header.dart';
import '../../../shared/widgets/akshara_status_chip.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../transport_models.dart';
import '../transport_providers.dart';
import '../widgets/transport_kpi_row.dart';
import '../widgets/transport_module_scaffold.dart';

/// TR-03 — Vehicles.
class TransportVehiclesScreen extends ConsumerWidget {
  const TransportVehiclesScreen({super.key});

  static const List<String> filterLabels = [
    'All',
    'Active',
    'Maintenance',
    'Retired',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(transportVehiclesLoadingProvider);
    final isError = ref.watch(transportVehiclesErrorProvider);
    final isEmpty = ref.watch(transportVehiclesEmptyProvider);
    final vehicles = ref.watch(transportFilteredVehiclesProvider);
    final filterIndex = ref.watch(transportVehiclesFilterProvider);

    return TransportModuleScaffold(
      screen: TransportScreen.vehicles,
      filters: filterLabels,
      selectedFilterIndex: filterIndex,
      onFilterSelected: (index) =>
          ref.read(transportVehiclesFilterProvider.notifier).state = index,
      body: _buildBody(
        context,
        isLoading: isLoading,
        isError: isError,
        isEmpty: isEmpty,
        vehicles: vehicles,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required bool isLoading,
    required bool isError,
    required bool isEmpty,
    required List<TransportVehicle> vehicles,
  }) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
        child: AksharaLoadingState(semanticLabel: 'Loading vehicles'),
      );
    }

    if (isError) {
      return const AksharaErrorState(message: 'Unable to load vehicles.');
    }

    if (isEmpty || vehicles.isEmpty) {
      return const AksharaEmptyState(
        message: 'No vehicles match the selected filters.',
        icon: Icons.directions_bus_outlined,
      );
    }

    final activeCount =
        vehicles.where((v) => v.status == TransportVehicleStatus.active).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TransportKpiRow(
          desktopColumns: 3,
          kpis: [
            TransportKpi(
              id: 'fleet',
              value: '${vehicles.length}',
              label: 'Fleet size',
              icon: Icons.directions_bus_outlined,
              accentName: 'primary',
            ),
            TransportKpi(
              id: 'active',
              value: '$activeCount',
              label: 'Active',
              icon: Icons.check_circle_outline,
              accentName: 'success',
            ),
            TransportKpi(
              id: 'avg_occ',
              value:
                  '${(vehicles.map((v) => v.occupancyPercent).reduce((a, b) => a + b) / vehicles.length).round()}%',
              label: 'Avg occupancy',
              icon: Icons.event_seat_outlined,
              accentName: 'neutral',
            ),
          ],
        ),
        const SizedBox(height: AksharaSpacing.s6),
        const AksharaSectionHeader(title: 'Vehicle registry'),
        const SizedBox(height: AksharaSpacing.s3),
        _VehiclesTable(vehicles: vehicles),
      ],
    );
  }
}

class _VehiclesTable extends StatelessWidget {
  const _VehiclesTable({required this.vehicles});

  final List<TransportVehicle> vehicles;

  @override
  Widget build(BuildContext context) {
    if (AdminLayout.isMobile(context)) {
      return Column(
        children: [
          for (final vehicle in vehicles) ...[
            _VehicleCard(vehicle: vehicle),
            const SizedBox(height: AksharaSpacing.s3),
          ],
        ],
      );
    }

    return Semantics(
      container: true,
      label: 'Vehicles table, ${vehicles.length} buses',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Material(
          child: DataTable(
            headingRowHeight: 48,
            dataRowMinHeight: 56,
            columns: const [
              DataColumn(label: Text('Bus')),
              DataColumn(label: Text('Registration')),
              DataColumn(label: Text('Capacity')),
              DataColumn(label: Text('Route')),
              DataColumn(label: Text('GPS')),
              DataColumn(label: Text('Occupancy')),
              DataColumn(label: Text('Status')),
            ],
            rows: [
              for (final vehicle in vehicles)
                DataRow(
                  onSelectChanged: (_) {},
                  cells: [
                    DataCell(Text(vehicle.busNumber)),
                    DataCell(Text(vehicle.registration)),
                    DataCell(Text('${vehicle.capacity}')),
                    DataCell(Text(vehicle.routeName)),
                    DataCell(Text(vehicle.gpsDeviceId)),
                    DataCell(Text('${vehicle.occupancyPercent}%')),
                    DataCell(_VehicleStatusChip(status: vehicle.status)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({required this.vehicle});

  final TransportVehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;

    return Semantics(
      label: 'Bus ${vehicle.busNumber}, ${vehicle.routeName}',
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
                    child: Text(vehicle.busNumber, style: text.titleSmall),
                  ),
                  _VehicleStatusChip(status: vehicle.status),
                ],
              ),
              Text(vehicle.registration, style: text.bodySmall),
              Text(
                '${vehicle.routeName} · ${vehicle.occupancyPercent}% occupancy',
                style: text.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VehicleStatusChip extends StatelessWidget {
  const _VehicleStatusChip({required this.status});

  final TransportVehicleStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (status) {
      TransportVehicleStatus.active => ('Active', KpiAccent.success),
      TransportVehicleStatus.maintenance => ('Maintenance', KpiAccent.warning),
      TransportVehicleStatus.retired => ('Retired', KpiAccent.neutral),
    };

    return AksharaStatusChip(label: label, tone: tone);
  }
}
