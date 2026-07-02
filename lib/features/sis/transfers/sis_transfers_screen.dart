import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/reports/akshara_report_export_service.dart';
import '../../../core/repositories/paginated_result.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../reports/sis_report_exporters.dart';
import '../sis_async_state.dart';
import '../sis_models.dart';
import '../widgets/sis_module_scaffold.dart';
import 'sis_transfers_provider.dart';

/// SIS-5 — Transfers / Exit log: date-ranged, status-filtered, paginated list
/// of exited students (transferred / alumni) with CSV + PDF export (XCT-1).
class SisTransfersScreen extends ConsumerWidget {
  const SisTransfersScreen({super.key});

  String _iso(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewState = ref.watch(sisTransfersViewStateProvider);
    final range = ref.watch(sisTransfersRangeProvider);
    final statusIndex = ref.watch(sisTransfersStatusIndexProvider);
    final records = viewState.data?.items ?? const <SisTransferRecord>[];

    return SisModuleScaffold(
      screen: SisScreen.transfers,
      filters: kSisTransfersStatusFilters,
      selectedFilterIndex: statusIndex,
      onFilterSelected: (index) {
        ref.read(sisTransfersStatusIndexProvider.notifier).state = index;
        ref.read(sisTransfersPageProvider.notifier).state = 1;
      },
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: QaTestKeys.sisTransfersDateRangeButton,
                  onPressed: () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      ref.read(sisTransfersRangeProvider.notifier).state =
                          SisTransfersRange(
                        fromDate: _iso(picked.start),
                        toDate: _iso(picked.end),
                      );
                      ref.read(sisTransfersPageProvider.notifier).state = 1;
                    }
                  },
                  icon: const Icon(Icons.date_range_outlined, size: 18),
                  label: Text(
                    range.fromDate == null
                        ? 'All dates'
                        : '${range.fromDate} → ${range.toDate}',
                  ),
                ),
              ),
              if (range.fromDate != null) ...[
                const SizedBox(width: AksharaSpacing.s2),
                IconButton(
                  tooltip: 'Clear range',
                  onPressed: () {
                    ref.read(sisTransfersRangeProvider.notifier).state =
                        const SisTransfersRange();
                    ref.read(sisTransfersPageProvider.notifier).state = 1;
                  },
                  icon: const Icon(Icons.clear),
                ),
              ],
            ],
          ),
          const SizedBox(height: AksharaSpacing.s3),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                key: QaTestKeys.sisTransfersExportCsvButton,
                onPressed: records.isEmpty
                    ? null
                    : () => _export(context, ref, records, pdf: false),
                icon: const Icon(Icons.download_outlined, size: 18),
                label: const Text('Export CSV'),
              ),
              const SizedBox(width: AksharaSpacing.s2),
              OutlinedButton.icon(
                key: QaTestKeys.sisTransfersExportPdfButton,
                onPressed: records.isEmpty
                    ? null
                    : () => _export(context, ref, records, pdf: true),
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                label: const Text('Export PDF'),
              ),
            ],
          ),
          const SizedBox(height: AksharaSpacing.s4),
          SisAsyncBody<PaginatedResult<SisTransferRecord>>(
            state: viewState,
            loadingLabel: 'Loading transfers and exits',
            emptyMessage: 'No transferred or alumni students in this range.',
            emptyIcon: Icons.transfer_within_a_station_outlined,
            onRetry: () => retrySisFuture(ref, sisTransfersFutureProvider),
            builder: (result) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final record in result.items)
                  _TransferRow(record: record),
                AksharaPaginationBar<SisTransferRecord>(
                  result: result,
                  onPageChanged: (page) =>
                      ref.read(sisTransfersPageProvider.notifier).state = page,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _export(
    BuildContext context,
    WidgetRef ref,
    List<SisTransferRecord> records, {
    required bool pdf,
  }) async {
    final exporters = SisReportExporters(
      ref.read(aksharaReportExportServiceProvider),
    );
    if (pdf) {
      await exporters.shareTransfersPdf(records);
    } else {
      await exporters.shareTransfersCsv(records);
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.sisTransfersExportSuccessSnackbar,
        content: Text(
          'Exit log ${pdf ? 'PDF' : 'CSV'} ready (${records.length} students)',
        ),
      ),
    );
  }
}

class _TransferRow extends StatelessWidget {
  const _TransferRow({required this.record});

  final SisTransferRecord record;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    final colors = context.colors;
    final exitedAt = record.exitedAt.length >= 10 && record.exitedAt[4] == '-'
        ? record.exitedAt.substring(0, 10)
        : record.exitedAt;
    final tone = record.status == SisStudentStatus.transferred
        ? KpiAccent.primary
        : KpiAccent.neutral;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: AksharaSpacing.s3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AksharaSpacing.s3),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AksharaSpacing.s4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(record.studentName, style: text.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (record.admissionNumber.isNotEmpty)
                        record.admissionNumber,
                      'Class ${record.classLabel}-${record.section}',
                      record.academicYear,
                    ].join(' · '),
                    style: text.bodySmall
                        .copyWith(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AksharaSpacing.s2),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AksharaStatusChip(
                  label: sisStudentStatusLabel(record.status),
                  tone: tone,
                ),
                const SizedBox(height: 2),
                Text('Exited $exitedAt', style: text.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
