import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/paginated_result.dart';

import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../hostel_models.dart';
import '../hostel_providers.dart';
import '../widgets/hostel_module_scaffold.dart';

/// HO-04 — Hostel Attendance.
class HostelAttendanceScreen extends ConsumerWidget {
  const HostelAttendanceScreen({super.key});

  static const List<String> filterLabels = [
    'All',
    'Present',
    'Absent',
    'On leave',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(hostelAttendanceLoadingProvider);
    final isError = ref.watch(hostelAttendanceErrorProvider);
    final isEmpty = ref.watch(hostelAttendanceEmptyProvider);
    final records = ref.watch(hostelFilteredAttendanceProvider);
    final filterIndex = ref.watch(hostelAttendanceFilterProvider);
    final pageResult = ref.watch(hostelAttendancePageResultProvider);

    return HostelModuleScaffold(
      screen: HostelScreen.attendance,
      filters: filterLabels,
      selectedFilterIndex: filterIndex,
      onFilterSelected: (index) =>
          ref.read(hostelAttendanceFilterProvider.notifier).state = index,
      body: _buildBody(
        context,
        ref,
        isLoading: isLoading,
        isError: isError,
        isEmpty: isEmpty,
        records: records,
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
    required List<HostelAttendanceRecord> records,
    required PaginatedResult<HostelAttendanceRecord>? pageResult,
  }) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
        child: AksharaLoadingState(
          semanticLabel: 'Loading hostel attendance',
        ),
      );
    }

    if (isError) {
      return const AksharaErrorState(
        message: 'Unable to load hostel attendance.',
      );
    }

    if (isEmpty || records.isEmpty) {
      return const AksharaEmptyState(
        message: 'No attendance records for the selected filters.',
        icon: Icons.fact_check_outlined,
      );
    }

    final missing = records
        .where((r) => r.overallStatus == HostelAttendanceStatus.absent)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (missing.isNotEmpty)
          AksharaWarningBanner(
            message:
                '${missing.length} student(s) missing — parent notification sent via Parent App',
            actionLabel: 'Review absentees',
            onAction: () => ref
                .read(hostelAttendanceFilterProvider.notifier)
                .state = filterLabels.indexOf('Absent'),
          ),
        if (missing.isNotEmpty) const SizedBox(height: AksharaSpacing.s4),
        const AksharaSectionHeader(title: 'Hostel attendance roster'),
        const SizedBox(height: AksharaSpacing.s3),
        _AttendanceTable(records: records),
        AksharaPaginatedListFooter<HostelAttendanceRecord>(
          result: pageResult,
          pageProvider: hostelAttendancePageProvider,
        ),
      ],
    );
  }
}

class _AttendanceTable extends StatelessWidget {
  const _AttendanceTable({required this.records});

  final List<HostelAttendanceRecord> records;

  String _statusLabel(HostelAttendanceStatus status) => switch (status) {
        HostelAttendanceStatus.present => 'P',
        HostelAttendanceStatus.absent => 'A',
        HostelAttendanceStatus.onLeave => 'L',
      };

  @override
  Widget build(BuildContext context) {
    if (AdminLayout.useCardLayout(context)) {
      return Column(
        children: [
          for (final record in records) ...[
            _AttendanceCard(
              record: record,
              statusLabel: _statusLabel,
            ),
            const SizedBox(height: AksharaSpacing.s3),
          ],
        ],
      );
    }

    return Semantics(
      container: true,
      label: 'Hostel attendance table, ${records.length} students',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Material(
          child: DataTable(
            headingRowHeight: 48,
            dataRowMinHeight: 52,
            columns: const [
              DataColumn(label: Text('Student')),
              DataColumn(label: Text('Room')),
              DataColumn(label: Text('Roll')),
              DataColumn(label: Text('Morning')),
              DataColumn(label: Text('Evening')),
              DataColumn(label: Text('Night')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Parent notified')),
            ],
            rows: [
              for (final record in records)
                DataRow(
                  cells: [
                    DataCell(Text(record.studentName)),
                    DataCell(Text(record.room)),
                    DataCell(Text(record.rollNumber)),
                    DataCell(Text(_statusLabel(record.morning))),
                    DataCell(Text(_statusLabel(record.evening))),
                    DataCell(Text(_statusLabel(record.night))),
                    DataCell(
                      _AttendanceStatusChip(status: record.overallStatus),
                    ),
                    DataCell(
                      Icon(
                        record.parentNotified
                            ? Icons.check_circle_outline
                            : Icons.remove_circle_outline,
                        size: 18,
                      ),
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
  const _AttendanceCard({
    required this.record,
    required this.statusLabel,
  });

  final HostelAttendanceRecord record;
  final String Function(HostelAttendanceStatus) statusLabel;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(AksharaSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(record.studentName, style: text.titleSmall),
            Text(
              '${record.room} · ${record.rollNumber}',
              style: text.bodyMedium,
            ),
            Text(
              'M/E/N: ${statusLabel(record.morning)}/${statusLabel(record.evening)}/${statusLabel(record.night)}',
              style: text.bodySmall,
            ),
            if (record.remark.isNotEmpty)
              Text(record.remark, style: text.bodySmall),
            const SizedBox(height: AksharaSpacing.s2),
            _AttendanceStatusChip(status: record.overallStatus),
          ],
        ),
      ),
    );
  }
}

class _AttendanceStatusChip extends StatelessWidget {
  const _AttendanceStatusChip({required this.status});

  final HostelAttendanceStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (status) {
      HostelAttendanceStatus.present => ('Present', KpiAccent.success),
      HostelAttendanceStatus.absent => ('Absent', KpiAccent.error),
      HostelAttendanceStatus.onLeave => ('On leave', KpiAccent.warning),
    };

    return AksharaStatusChip(
      label: label,
      tone: tone,
      semanticLabel: 'Attendance status: $label',
    );
  }
}
