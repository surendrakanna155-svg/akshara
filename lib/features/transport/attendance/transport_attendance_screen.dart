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

/// TR-06 — Transport Attendance.
class TransportAttendanceScreen extends ConsumerWidget {
  const TransportAttendanceScreen({super.key});

  static const List<String> filterLabels = [
    'All',
    'Picked',
    'Waiting',
    'Absent',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(transportAttendanceLoadingProvider);
    final isError = ref.watch(transportAttendanceErrorProvider);
    final isEmpty = ref.watch(transportAttendanceEmptyProvider);
    final records = ref.watch(transportFilteredAttendanceProvider);
    final filterIndex = ref.watch(transportAttendanceFilterProvider);
    final pageResult = ref.watch(transportAttendancePageResultProvider);

    return TransportModuleScaffold(
      screen: TransportScreen.attendance,
      filters: filterLabels,
      selectedFilterIndex: filterIndex,
      onFilterSelected: (index) =>
          ref.read(transportAttendanceFilterProvider.notifier).state = index,
      body: _buildBody(
        context,
        isLoading: isLoading,
        isError: isError,
        isEmpty: isEmpty,
        records: records,
        pageResult: pageResult,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required bool isLoading,
    required bool isError,
    required bool isEmpty,
    required List<TransportAttendanceRecord> records,
    required PaginatedResult<TransportAttendanceRecord>? pageResult,
  }) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
        child: AksharaLoadingState(
          semanticLabel: 'Loading transport attendance',
        ),
      );
    }

    if (isError) {
      return const AksharaErrorState(
        message: 'Unable to load transport attendance.',
      );
    }

    if (isEmpty || records.isEmpty) {
      return const AksharaEmptyState(
        message: 'No attendance records for the selected filters.',
        icon: Icons.fact_check_outlined,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AksharaSectionHeader(title: 'AM pickup attendance'),
        const SizedBox(height: AksharaSpacing.s3),
        _AttendanceTable(records: records),
        AksharaPaginatedListFooter<TransportAttendanceRecord>(
          result: pageResult,
          pageProvider: transportAttendancePageProvider,
        ),
      ],
    );
  }
}

class _AttendanceTable extends StatelessWidget {
  const _AttendanceTable({required this.records});

  final List<TransportAttendanceRecord> records;

  @override
  Widget build(BuildContext context) {
    if (AdminLayout.isMobile(context)) {
      return Column(
        children: [
          for (final record in records) ...[
            _AttendanceCard(record: record),
            const SizedBox(height: AksharaSpacing.s3),
          ],
        ],
      );
    }

    return Semantics(
      container: true,
      label: 'Attendance table, ${records.length} records',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Material(
          child: DataTable(
            headingRowHeight: 48,
            dataRowMinHeight: 56,
            columns: const [
              DataColumn(label: Text('Student')),
              DataColumn(label: Text('Stop')),
              DataColumn(label: Text('Route')),
              DataColumn(label: Text('Scheduled')),
              DataColumn(label: Text('Actual')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Parent notified')),
            ],
            rows: [
              for (final record in records)
                DataRow(
                  onSelectChanged: (_) {},
                  cells: [
                    DataCell(Text(record.studentName)),
                    DataCell(Text(record.stopName)),
                    DataCell(Text(record.routeName)),
                    DataCell(Text(record.scheduledTime)),
                    DataCell(Text(record.actualTime)),
                    DataCell(_AttendanceStatusChip(status: record.status)),
                    DataCell(
                      Text(record.parentNotified ? 'Yes' : 'No'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttendanceCard extends StatelessWidget {
  const _AttendanceCard({required this.record});

  final TransportAttendanceRecord record;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;

    return Semantics(
      label:
          'Attendance ${record.studentName}, ${record.status.name}, scheduled ${record.scheduledTime}',
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
                    child: Text(record.studentName, style: text.titleSmall),
                  ),
                  _AttendanceStatusChip(status: record.status),
                ],
              ),
              Text(
                '${record.stopName} · ${record.routeName}',
                style: text.bodySmall,
              ),
              Text(
                'Scheduled ${record.scheduledTime} · Actual ${record.actualTime}',
                style: text.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttendanceStatusChip extends StatelessWidget {
  const _AttendanceStatusChip({required this.status});

  final TransportAttendanceStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (status) {
      TransportAttendanceStatus.picked => ('Picked', KpiAccent.success),
      TransportAttendanceStatus.waiting => ('Waiting', KpiAccent.warning),
      TransportAttendanceStatus.absent => ('Absent', KpiAccent.error),
      TransportAttendanceStatus.notScheduled => ('Not scheduled', KpiAccent.neutral),
    };

    return AksharaStatusChip(label: label, tone: tone);
  }
}
