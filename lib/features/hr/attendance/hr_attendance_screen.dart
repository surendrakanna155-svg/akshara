import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/reports/akshara_report_export_service.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../../router/route_names.dart';
import '../../../shared/widgets/akshara_empty_state.dart';
import '../../../shared/widgets/akshara_error_state.dart';
import '../../../shared/widgets/akshara_loading_state.dart';
import '../../../shared/widgets/akshara_section_header.dart';
import '../../../shared/widgets/akshara_status_chip.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../../staff_attendance/staff_attendance_providers.dart';
import '../../staff_attendance/widgets/staff_check_in_card.dart';
import '../hr_models.dart';
import '../hr_providers.dart';
import '../hr_report_models.dart';
import '../reports/hr_export_providers.dart';
import '../reports/hr_report_exporters.dart';
import '../widgets/hr_module_scaffold.dart';
import '../widgets/hr_segment_panel.dart';
import '../widgets/hr_trend_chart.dart';

/// HR-04 — Staff Attendance.
class HrAttendanceScreen extends ConsumerWidget {
  const HrAttendanceScreen({super.key});

  static const List<String> filterLabels = [
    'All',
    'Present',
    'Late',
    'On leave',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(hrAttendanceLoadingProvider);
    final isError = ref.watch(hrAttendanceErrorProvider);
    final isEmpty = ref.watch(hrAttendanceEmptyProvider);
    final data = ref.watch(hrAttendanceProvider);
    final records = ref.watch(hrFilteredAttendanceProvider);
    final filterIndex = ref.watch(hrAttendanceFilterProvider);

    return HrModuleScaffold(
      screen: HrScreen.attendance,
      filters: filterLabels,
      selectedFilterIndex: filterIndex,
      onFilterSelected: (index) =>
          ref.read(hrAttendanceFilterProvider.notifier).state = index,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // O5 — staff biometric self check-in/out. Always visible (does not
            // depend on the attendance list); only staff hold the permission the
            // backend enforces on the write.
            StaffCheckInCard(
              // Deferred: the reliability/biometric stack is resolved only on
              // tap (ref.read in the callback), never at screen-build time.
              onRecord: (event) =>
                  ref.read(staffAttendanceControllerProvider).record(event),
              // Slice 3 — settings entry point + the FACE_NOT_ENROLLED
              // call-to-action both open the same enrollment flow.
              onOpenEnrollment: () =>
                  context.push(RouteNames.staffFaceEnrollment),
            ),
            const SizedBox(height: AksharaSpacing.s4),
            // HR-6 — monthly attendance muster export (inferred from the
            // staff_check_ins ledger server-side). Always available on this
            // viewHr-gated screen, independent of the attendance list state.
            const _MusterExportBar(),
            const SizedBox(height: AksharaSpacing.s6),
            _buildBody(
              context,
              isLoading: isLoading,
              isError: isError,
              isEmpty: isEmpty,
              data: data,
              records: records,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required bool isLoading,
    required bool isError,
    required bool isEmpty,
    required HrAttendanceData? data,
    required List<HrAttendanceRecord> records,
  }) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
        child: AksharaLoadingState(semanticLabel: 'Loading staff attendance'),
      );
    }

    if (isError) {
      return const AksharaErrorState(
        message: 'Unable to load staff attendance.',
      );
    }

    if (isEmpty || data == null || records.isEmpty) {
      return const AksharaEmptyState(
        message: 'No attendance records for the selected filters.',
        icon: Icons.fact_check_outlined,
      );
    }

    final isMobile = AdminLayout.isMobile(context);
    final chartHeight = isMobile ? 240.0 : 280.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AksharaSectionHeader(title: 'Staff attendance'),
        Text(data.summaryNote, style: context.aksharaText.bodySmall),
        const SizedBox(height: AksharaSpacing.s4),
        _AttendanceTable(records: records),
        const SizedBox(height: AksharaSpacing.s6),
        if (isMobile) ...[
          HrTrendChart(
            title: 'Weekly attendance %',
            points: data.attendanceTrend,
            height: chartHeight,
          ),
          const SizedBox(height: AksharaSpacing.s4),
          HrSegmentPanel(
            title: 'By department',
            segments: data.departmentBreakdown,
            height: chartHeight,
          ),
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: HrTrendChart(
                  title: 'Weekly attendance %',
                  points: data.attendanceTrend,
                  height: chartHeight,
                ),
              ),
              const SizedBox(width: AksharaSpacing.s6),
              Expanded(
                child: HrSegmentPanel(
                  title: 'By department',
                  segments: data.departmentBreakdown,
                  height: chartHeight,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// HR-6 — monthly attendance muster export bar. Fetches the muster for the
/// selected month (defaults to the current month) on tap and shares it as a
/// grid CSV / PDF via the shared XCT-1 export service.
class _MusterExportBar extends ConsumerWidget {
  const _MusterExportBar();

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function(HrReportExporters exporters, HrAttendanceMuster muster)
        action,
    String label,
  ) async {
    final month = ref.read(hrMusterMonthProvider);
    final exporters =
        HrReportExporters(ref.read(aksharaReportExportServiceProvider));
    try {
      final muster = await ref.read(hrAttendanceMusterProvider(month).future);
      await action(exporters, muster);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: QaTestKeys.hrReportExportSuccessSnackbar,
          content: Text(label),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to build the muster export.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(hrMusterMonthProvider);
    return Semantics(
      label: 'Attendance muster export actions',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Monthly muster · $month',
              style: context.aksharaText.titleSmall),
          const SizedBox(height: AksharaSpacing.s2),
          Wrap(
            spacing: AksharaSpacing.s3,
            runSpacing: AksharaSpacing.s3,
            children: [
              OutlinedButton.icon(
                key: QaTestKeys.hrMusterExportButton,
                onPressed: () => _run(
                  context,
                  ref,
                  (e, m) => e.shareMusterPdf(m),
                  'Attendance muster ($month) PDF ready',
                ),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Muster PDF'),
              ),
              OutlinedButton.icon(
                onPressed: () => _run(
                  context,
                  ref,
                  (e, m) => e.shareMusterCsv(m),
                  'Attendance muster ($month) Excel CSV ready',
                ),
                icon: const Icon(Icons.table_chart_outlined),
                label: const Text('Muster Excel'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AttendanceTable extends StatelessWidget {
  const _AttendanceTable({required this.records});

  final List<HrAttendanceRecord> records;

  @override
  Widget build(BuildContext context) {
    if (AdminLayout.useCardLayout(context)) {
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
      label: 'Staff attendance table, ${records.length} records',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Material(
          child: DataTable(
            headingRowHeight: 48,
            dataRowMinHeight: 56,
            columns: const [
              DataColumn(label: Text('Employee')),
              DataColumn(label: Text('Department')),
              DataColumn(label: Text('Check-in')),
              DataColumn(label: Text('Check-out')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Geo')),
              DataColumn(label: Text('Face')),
            ],
            rows: [
              for (final record in records)
                DataRow(
                  cells: [
                    DataCell(Text(record.employeeName)),
                    DataCell(Text(record.department.name)),
                    DataCell(Text(record.checkIn)),
                    DataCell(Text(record.checkOut)),
                    DataCell(_AttendanceStatusChip(status: record.status)),
                    DataCell(_VerificationChip(verified: record.geoVerified)),
                    DataCell(_VerificationChip(verified: record.faceVerified)),
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

  final HrAttendanceRecord record;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;

    return Semantics(
      label:
          '${record.employeeName}, ${record.checkIn} to ${record.checkOut}',
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(record.employeeName, style: text.titleSmall),
              Text(
                '${record.checkIn} – ${record.checkOut}',
                style: text.bodySmall,
              ),
              const SizedBox(height: AksharaSpacing.s2),
              _AttendanceStatusChip(status: record.status),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttendanceStatusChip extends StatelessWidget {
  const _AttendanceStatusChip({required this.status});

  final HrAttendanceStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (status) {
      HrAttendanceStatus.present => ('Present', KpiAccent.success),
      HrAttendanceStatus.absent => ('Absent', KpiAccent.error),
      HrAttendanceStatus.late => ('Late', KpiAccent.warning),
      HrAttendanceStatus.onLeave => ('On leave', KpiAccent.primary),
      HrAttendanceStatus.halfDay => ('Half day', KpiAccent.neutral),
    };

    return AksharaStatusChip(label: label, tone: tone);
  }
}

class _VerificationChip extends StatelessWidget {
  const _VerificationChip({required this.verified});

  final bool verified;

  @override
  Widget build(BuildContext context) {
    return AksharaStatusChip(
      label: verified ? 'Yes' : 'No',
      tone: verified ? KpiAccent.success : KpiAccent.neutral,
    );
  }
}
