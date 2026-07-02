import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/paginated_result.dart';
import '../../../core/security/permissions.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../../core/widgets/whatsapp_contact_button.dart';

import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../transport_driver_actions.dart';
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
        ref,
        isLoading: isLoading,
        isError: isError,
        isEmpty: isEmpty,
        drivers: drivers,
        pageResult: pageResult,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref, {
    required bool isLoading,
    required bool isError,
    required bool isEmpty,
    required List<TransportDriver> drivers,
    required PaginatedResult<TransportDriver>? pageResult,
  }) {
    final addButton = Align(
      alignment: Alignment.centerRight,
      child: AksharaManageAction(
        permission: Permission.manageTransport,
        child: FilledButton.icon(
          key: QaTestKeys.transportAddDriverButton,
          onPressed: () => showDriverFormDialog(context, ref),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add driver'),
        ),
      ),
    );

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
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          addButton,
          const SizedBox(height: AksharaSpacing.s4),
          const AksharaEmptyState(
            message: 'No drivers match the selected filters.',
            icon: Icons.person_outline,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        addButton,
        const SizedBox(height: AksharaSpacing.s4),
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

class _DriversTable extends ConsumerWidget {
  const _DriversTable({required this.drivers});

  final List<TransportDriver> drivers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (AdminLayout.useCardLayout(context)) {
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
        DataColumn(label: Text('Actions')),
      ],
      rowCount: drivers.length,
      dataRowMinHeight: 56,
      semanticLabel: 'Drivers table, ${drivers.length} drivers',
      rowBuilder: (index) {
        final driver = drivers[index];
        return DataRow(
          cells: [
            DataCell(Text(driver.name)),
            DataCell(Text(driver.licenseNumber)),
            DataCell(Text(driver.licenseExpiry)),
            DataCell(Text(driver.phone)),
            DataCell(Text(driver.assignedBus)),
            DataCell(Text(driver.attendancePercent)),
            DataCell(Text(driver.rating)),
            DataCell(_DriverStatusChip(status: driver.status)),
            DataCell(_DriverActions(driver: driver)),
          ],
        );
      },
    );
  }
}

class _DriverActions extends ConsumerWidget {
  const _DriverActions({required this.driver});

  final TransportDriver driver;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        WhatsAppContactButton(
          phone: driver.phone,
          style: WhatsAppButtonStyle.icon,
          label: 'WhatsApp ${driver.name}',
          message: _driverMessage(driver),
        ),
        AksharaManageAction(
          permission: Permission.manageTransport,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                key: QaTestKeys.transportEditDriverButton(driver.id),
                icon: const Icon(Icons.edit_outlined, size: 18),
                tooltip: 'Edit driver',
                visualDensity: VisualDensity.compact,
                onPressed: () =>
                    showDriverFormDialog(context, ref, driver: driver),
              ),
              IconButton(
                key: QaTestKeys.transportDeleteDriverButton(driver.id),
                icon: const Icon(Icons.delete_outline, size: 18),
                tooltip: 'Delete driver',
                visualDensity: VisualDensity.compact,
                onPressed: () => confirmDeleteDriver(context, ref, driver),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DriverCard extends ConsumerWidget {
  const _DriverCard({required this.driver});

  final TransportDriver driver;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              const SizedBox(height: AksharaSpacing.s2),
              _DriverActions(driver: driver),
            ],
          ),
        ),
      ),
    );
  }
}

String _driverMessage(TransportDriver driver) =>
    'Hello ${driver.name}, this is from the school transport office regarding '
    'bus ${driver.assignedBus}. ';

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
