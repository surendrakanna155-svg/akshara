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

/// INV-05 — Maintenance.
class InventoryMaintenanceScreen extends ConsumerWidget {
  const InventoryMaintenanceScreen({super.key});

  static const List<String> filterLabels = [
    'All',
    'Scheduled',
    'In progress',
    'Overdue',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(inventoryMaintenanceLoadingProvider);
    final isError = ref.watch(inventoryMaintenanceErrorProvider);
    final isEmpty = ref.watch(inventoryMaintenanceEmptyProvider);
    final records = ref.watch(inventoryFilteredMaintenanceProvider);
    final filterIndex = ref.watch(inventoryMaintenanceFilterProvider);

    return InventoryModuleScaffold(
      screen: InventoryScreen.maintenance,
      filters: filterLabels,
      selectedFilterIndex: filterIndex,
      onFilterSelected: (index) =>
          ref.read(inventoryMaintenanceFilterProvider.notifier).state = index,
      body: _buildBody(
        context,
        isLoading: isLoading,
        isError: isError,
        isEmpty: isEmpty,
        records: records,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required bool isLoading,
    required bool isError,
    required bool isEmpty,
    required List<InventoryMaintenanceRecord> records,
  }) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
        child: AksharaLoadingState(
          semanticLabel: 'Loading maintenance records',
        ),
      );
    }

    if (isError) {
      return const AksharaErrorState(
        message: 'Unable to load maintenance records.',
      );
    }

    if (isEmpty || records.isEmpty) {
      return const AksharaEmptyState(
        message: 'No maintenance records match the selected filters.',
        icon: Icons.build_outlined,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AksharaSectionHeader(title: 'Maintenance schedule'),
        const SizedBox(height: AksharaSpacing.s3),
        _MaintenanceTable(records: records),
        const SizedBox(height: AksharaSpacing.s6),
        AksharaInsightCard(
          message:
              'Maintenance costs link to Finance budget codes (FN-BUD-MAINT-2026). Technicians reference HR employee IDs.',
          actionLabel: 'Open Finance',
          icon: Icons.account_balance_outlined,
          semanticLabelPrefix: 'Finance integration',
          onAction: () => context.go(RouteNames.financeDashboard),
        ),
      ],
    );
  }
}

class _MaintenanceTable extends StatelessWidget {
  const _MaintenanceTable({required this.records});

  final List<InventoryMaintenanceRecord> records;

  @override
  Widget build(BuildContext context) {
    if (AdminLayout.isMobile(context)) {
      return Column(
        children: [
          for (final record in records) ...[
            _MaintenanceCard(record: record),
            const SizedBox(height: AksharaSpacing.s3),
          ],
        ],
      );
    }

    return Semantics(
      container: true,
      label: 'Maintenance schedule, ${records.length} records',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Material(
          child: DataTable(
            headingRowHeight: 48,
            dataRowMinHeight: 52,
            columns: const [
              DataColumn(label: Text('Asset')),
              DataColumn(label: Text('Type')),
              DataColumn(label: Text('Scheduled')),
              DataColumn(label: Text('Technician')),
              DataColumn(label: Text('HR ID')),
              DataColumn(label: Text('Cost')),
              DataColumn(label: Text('Status')),
            ],
            rows: [
              for (final record in records)
                DataRow(
                  cells: [
                    DataCell(Text(record.assetName)),
                    DataCell(Text(record.maintenanceType)),
                    DataCell(Text(record.scheduledDate)),
                    DataCell(Text(record.technician)),
                    DataCell(Text(record.hrTechnicianId)),
                    DataCell(Text(record.estimatedCost)),
                    DataCell(_MaintenanceStatusChip(status: record.status)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MaintenanceCard extends StatelessWidget {
  const _MaintenanceCard({required this.record});

  final InventoryMaintenanceRecord record;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;

    return Semantics(
      label: 'Maintenance ${record.assetTag}, ${record.maintenanceType}',
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(record.assetName, style: text.titleSmall),
              const SizedBox(height: AksharaSpacing.s2),
              Text(record.maintenanceType, style: text.bodyMedium),
              Text(
                '${record.technician} · ${record.estimatedCost} · ${record.scheduledDate}',
                style: text.bodySmall,
              ),
              const SizedBox(height: AksharaSpacing.s2),
              _MaintenanceStatusChip(status: record.status),
            ],
          ),
        ),
      ),
    );
  }
}

class _MaintenanceStatusChip extends StatelessWidget {
  const _MaintenanceStatusChip({required this.status});

  final InventoryMaintenanceStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (status) {
      InventoryMaintenanceStatus.scheduled => ('Scheduled', KpiAccent.primary),
      InventoryMaintenanceStatus.inProgress => ('In progress', KpiAccent.warning),
      InventoryMaintenanceStatus.completed => ('Completed', KpiAccent.success),
      InventoryMaintenanceStatus.overdue => ('Overdue', KpiAccent.error),
    };

    return AksharaStatusChip(
      label: label,
      tone: tone,
      semanticLabel: 'Maintenance status: $label',
    );
  }
}
