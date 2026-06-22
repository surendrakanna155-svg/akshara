import 'package:flutter/material.dart';

import '../../../../shared/widgets/widgets.dart';
import '../../../../theme/spacing.dart';
import '../../../admin/admin_layout.dart';
import '../../admissions_models.dart';
import '../../widgets/admissions_application_status_chip.dart';

/// Report data tables for AD-09.
class AdmissionsSourceReportTable extends StatelessWidget {
  const AdmissionsSourceReportTable({super.key, required this.rows});

  final List<SourceLeadAnalysisRow> rows;

  @override
  Widget build(BuildContext context) {
    return _ReportTable(
      semanticLabel: 'Source-wise lead analysis',
      columns: const ['Source', 'Leads', 'Converted', 'Rate'],
      rows: [
        for (final row in rows)
          [
            row.source.label,
            '${row.leads}',
            '${row.converted}',
            '${row.conversionRate.toStringAsFixed(1)}%',
          ],
      ],
    );
  }
}

class AdmissionsCounselorReportTable extends StatelessWidget {
  const AdmissionsCounselorReportTable({super.key, required this.rows});

  final List<CounselorPerformanceRow> rows;

  @override
  Widget build(BuildContext context) {
    return _ReportTable(
      semanticLabel: 'Counselor performance report',
      columns: const [
        'Counselor',
        'Leads',
        'Applications',
        'Approved',
        'Rate',
      ],
      rows: [
        for (final row in rows)
          [
            row.counselor,
            '${row.leads}',
            '${row.applications}',
            '${row.approved}',
            '${row.conversionRate.toStringAsFixed(1)}%',
          ],
      ],
    );
  }
}

class AdmissionsApplicationReportTable extends StatelessWidget {
  const AdmissionsApplicationReportTable({super.key, required this.rows});

  final List<ApplicationStatusReportRow> rows;

  @override
  Widget build(BuildContext context) {
    if (AdminLayout.useCardLayout(context)) {
      return Semantics(
        container: true,
        label: 'Application status report',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final row in rows) ...[
              AksharaKeyValueCard(
                titleWidget:
                    AdmissionsApplicationStatusChip(status: row.status),
                entries: [
                  ('Count', '${row.count}'),
                  ('Share', '${row.percent.toStringAsFixed(1)}%'),
                ],
              ),
              const SizedBox(height: AksharaSpacing.s3),
            ],
          ],
        ),
      );
    }

    return Semantics(
      container: true,
      label: 'Application status report',
      child: Material(
        type: MaterialType.transparency,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Count')),
              DataColumn(label: Text('Share')),
            ],
            rows: [
              for (final row in rows)
                DataRow(
                  cells: [
                    DataCell(
                      AdmissionsApplicationStatusChip(status: row.status),
                    ),
                    DataCell(Text('${row.count}')),
                    DataCell(Text('${row.percent.toStringAsFixed(1)}%')),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportTable extends StatelessWidget {
  const _ReportTable({
    required this.semanticLabel,
    required this.columns,
    required this.rows,
  });

  final String semanticLabel;
  final List<String> columns;
  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) {
    if (AdminLayout.useCardLayout(context)) {
      return Semantics(
        container: true,
        label: semanticLabel,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final row in rows) ...[
              AksharaKeyValueCard(
                title: row.isNotEmpty ? row.first : '',
                entries: [
                  for (var i = 1; i < columns.length && i < row.length; i++)
                    (columns[i], row[i]),
                ],
              ),
              const SizedBox(height: AksharaSpacing.s3),
            ],
          ],
        ),
      );
    }

    return Semantics(
      container: true,
      label: semanticLabel,
      child: Material(
        type: MaterialType.transparency,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: [for (final col in columns) DataColumn(label: Text(col))],
            rows: [
              for (final row in rows)
                DataRow(
                  cells: [for (final cell in row) DataCell(Text(cell))],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
