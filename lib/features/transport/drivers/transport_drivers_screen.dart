import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/paginated_result.dart';

import '../../../shared/widgets/widgets.dart';
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
    final pageResult = ref.watch(transportDriversPageResultProvider);

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
        pageResult: pageResult,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required bool isLoading,
    required bool isError,
    required bool isEmpty,
    required List<TransportDriver> drivers,
    required PaginatedResult<TransportDriver>? pageResult,
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
        AksharaPaginatedListFooter<TransportDriver>(
          result: pageResult,
          pageProvider: transportDriversPageProvider,
        ),
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

    return AksharaVirtualizedDataTable(
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
      rowCount: drivers.length,
      dataRowMinHeight: 56,
      semanticLabel: 'Drivers table, ${drivers.length} drivers',
      rowBuilder: (index) {
        final driver = drivers[index];
        return DataRow(
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
        );
      },
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
