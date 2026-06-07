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
import '../widgets/transport_module_scaffold.dart';

/// TR-04 — Drivers.
class TransportDriversScreen extends ConsumerWidget {
  const TransportDriversScreen({super.key});

  static const List<String> filterLabels = [
    'All',
    'Active',
    'On leave',
    'Inactive',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(transportDriversLoadingProvider);
    final isError = ref.watch(transportDriversErrorProvider);
    final isEmpty = ref.watch(transportDriversEmptyProvider);
    final drivers = ref.watch(transportFilteredDriversProvider);
    final filterIndex = ref.watch(transportDriversFilterProvider);

    return TransportModuleScaffold(
      screen: TransportScreen.drivers,
      filters: filterLabels,
      selectedFilterIndex: filterIndex,
      onFilterSelected: (index) =>
          ref.read(transportDriversFilterProvider.notifier).state = index,
      body: _buildBody(
        context,
        isLoading: isLoading,
        isError: isError,
        isEmpty: isEmpty,
        drivers: drivers,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required bool isLoading,
    required bool isError,
    required bool isEmpty,
    required List<TransportDriver> drivers,
  }) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
        child: AksharaLoadingState(semanticLabel: 'Loading drivers'),
      );
    }

    if (isError) {
      return const AksharaErrorState(message: 'Unable to load drivers.');
    }

    if (isEmpty || drivers.isEmpty) {
      return const AksharaEmptyState(
        message: 'No drivers match the selected filters.',
        icon: Icons.person_outline,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AksharaSectionHeader(title: 'Driver roster'),
        const SizedBox(height: AksharaSpacing.s3),
        _DriversTable(drivers: drivers),
      ],
    );
  }
}

class _DriversTable extends StatelessWidget {
  const _DriversTable({required this.drivers});

  final List<TransportDriver> drivers;

  @override
  Widget build(BuildContext context) {
    if (AdminLayout.isMobile(context)) {
      return Column(
        children: [
          for (final driver in drivers) ...[
            _DriverCard(driver: driver),
            const SizedBox(height: AksharaSpacing.s3),
          ],
        ],
      );
    }

    return Semantics(
      container: true,
      label: 'Drivers table, ${drivers.length} drivers',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Material(
          child: DataTable(
            headingRowHeight: 48,
            dataRowMinHeight: 56,
            columns: const [
              DataColumn(label: Text('Name')),
              DataColumn(label: Text('License')),
              DataColumn(label: Text('Expiry')),
              DataColumn(label: Text('Phone')),
              DataColumn(label: Text('Bus')),
              DataColumn(label: Text('Attendance')),
              DataColumn(label: Text('Rating')),
              DataColumn(label: Text('Status')),
            ],
            rows: [
              for (final driver in drivers)
                DataRow(
                  onSelectChanged: (_) {},
                  cells: [
                    DataCell(Text(driver.name)),
                    DataCell(Text(driver.licenseNumber)),
                    DataCell(Text(driver.licenseExpiry)),
                    DataCell(Text(driver.phone)),
                    DataCell(Text(driver.assignedBus)),
                    DataCell(Text(driver.attendancePercent)),
                    DataCell(Text(driver.rating)),
                    DataCell(_DriverStatusChip(status: driver.status)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DriverCard extends StatelessWidget {
  const _DriverCard({required this.driver});

  final TransportDriver driver;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;

    return Semantics(
      label: 'Driver ${driver.name}, bus ${driver.assignedBus}',
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
                    child: Text(driver.name, style: text.titleSmall),
                  ),
                  _DriverStatusChip(status: driver.status),
                ],
              ),
              Text('Bus ${driver.assignedBus}', style: text.bodySmall),
              Text(
                'Rating ${driver.rating} · Attendance ${driver.attendancePercent}',
                style: text.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DriverStatusChip extends StatelessWidget {
  const _DriverStatusChip({required this.status});

  final TransportDriverStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (status) {
      TransportDriverStatus.active => ('Active', KpiAccent.success),
      TransportDriverStatus.onLeave => ('On leave', KpiAccent.warning),
      TransportDriverStatus.inactive => ('Inactive', KpiAccent.neutral),
    };

    return AksharaStatusChip(label: label, tone: tone);
  }
}
