import 'package:flutter/material.dart';

import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import '../../../admin/admin_layout.dart';
import '../../admissions_models.dart';
import '../../widgets/admissions_application_status_chip.dart';

/// Applications table for AD-03 with mobile card fallback.
class AdmissionsApplicationsTable extends StatelessWidget {
  const AdmissionsApplicationsTable({
    super.key,
    required this.applications,
    this.onView,
  });

  final List<AdmissionsApplication> applications;
  final void Function(AdmissionsApplication app)? onView;

  @override
  Widget build(BuildContext context) {
    if (AdminLayout.isMobile(context)) {
      return Column(
        children: [
          for (final app in applications) ...[
            _ApplicationMobileCard(app: app, onView: onView),
            const SizedBox(height: AksharaSpacing.s3),
          ],
        ],
      );
    }

    return Semantics(
      container: true,
      label: 'Applications table, ${applications.length} records',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 48,
          dataRowMinHeight: 52,
          dataRowMaxHeight: 72,
          columns: const [
            DataColumn(label: Text('App ID')),
            DataColumn(label: Text('Student')),
            DataColumn(label: Text('Class')),
            DataColumn(label: Text('Parent')),
            DataColumn(label: Text('Submitted')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Docs')),
            DataColumn(label: Text('Counselor')),
            DataColumn(label: Text('Actions')),
          ],
          rows: [
            for (final app in applications)
              DataRow(
                cells: [
                  DataCell(Text(app.id)),
                  DataCell(Text(app.studentName)),
                  DataCell(Text(app.classLabel)),
                  DataCell(Text(app.parentName)),
                  DataCell(Text(app.submittedLabel)),
                  DataCell(AdmissionsApplicationStatusChip(status: app.status)),
                  DataCell(Text('${app.documentsComplete}/${app.documentsTotal}')),
                  DataCell(Text(app.counselor)),
                  DataCell(
                    IconButton(
                      icon: const Icon(Icons.visibility_outlined, size: 20),
                      tooltip: 'View application',
                      onPressed: onView == null ? null : () => onView!(app),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ApplicationMobileCard extends StatelessWidget {
  const _ApplicationMobileCard({required this.app, this.onView});

  final AdmissionsApplication app;
  final void Function(AdmissionsApplication app)? onView;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Semantics(
      label:
          'Application ${app.id}, ${app.studentName}, status ${app.status.label}',
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AksharaSpacing.s3),
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    app.id,
                    style: text.labelLarge.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  AdmissionsApplicationStatusChip(status: app.status),
                ],
              ),
              Text(
                '${app.studentName} · Class ${app.classLabel}',
                style: text.bodyMedium,
              ),
              Text(
                app.parentName,
                style: text.bodySmall.copyWith(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: AksharaSpacing.s2),
              Text(
                'Docs ${app.documentsComplete}/${app.documentsTotal} · ${app.counselor}',
                style: text.bodySmall.copyWith(color: colors.onSurfaceVariant),
              ),
              Text(
                'Submitted ${app.submittedLabel}',
                style: text.bodySmall.copyWith(color: colors.onSurfaceVariant),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onView == null ? null : () => onView!(app),
                  child: const Text('View'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
