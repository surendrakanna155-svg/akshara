import 'package:flutter/material.dart';

import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import '../../../admin/admin_layout.dart';
import '../../admissions_models.dart';
import '../../widgets/admissions_document_status_chip.dart';

/// Document verification table with mobile card fallback (AD-06).
class AdmissionsDocumentsTable extends StatelessWidget {
  const AdmissionsDocumentsTable({
    super.key,
    required this.documents,
    this.selectedId,
    this.onSelect,
    this.onVerify,
  });

  final List<StudentDocumentRecord> documents;
  final String? selectedId;
  final ValueChanged<StudentDocumentRecord>? onSelect;
  final ValueChanged<StudentDocumentRecord>? onVerify;

  @override
  Widget build(BuildContext context) {
    if (AdminLayout.useCardLayout(context)) {
      return Column(
        children: [
          for (final doc in documents) ...[
            _DocumentMobileCard(
              document: doc,
              selected: doc.id == selectedId,
              onTap: onSelect == null ? null : () => onSelect!(doc),
              onVerify: onVerify == null ? null : () => onVerify!(doc),
            ),
            const SizedBox(height: AksharaSpacing.s3),
          ],
        ],
      );
    }

    return Semantics(
      container: true,
      label: 'Documents table, ${documents.length} records',
      child: Material(
        type: MaterialType.transparency,
        child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 48,
          columns: const [
            DataColumn(label: Text('Student')),
            DataColumn(label: Text('Document')),
            DataColumn(label: Text('Required')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Uploaded')),
            DataColumn(label: Text('Verified by')),
            DataColumn(label: Text('Actions')),
          ],
          rows: [
            for (final doc in documents)
              DataRow(
                selected: doc.id == selectedId,
                onSelectChanged: onSelect == null
                    ? null
                    : (_) => onSelect!(doc),
                cells: [
                  DataCell(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(doc.studentName),
                        Text(
                          'Class ${doc.classLabel}',
                          style: context.aksharaText.bodySmall.copyWith(
                            color: context.colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  DataCell(Text(doc.documentType.label)),
                  DataCell(Text(doc.isRequired ? 'Yes' : 'No')),
                  DataCell(AdmissionsDocumentStatusChip(status: doc.status)),
                  DataCell(Text(doc.uploadedLabel)),
                  DataCell(Text(doc.verifiedBy ?? '—')),
                  DataCell(
                    IconButton(
                      icon: const Icon(Icons.verified_outlined, size: 20),
                      tooltip: 'Verify',
                      onPressed:
                          onVerify == null ? null : () => onVerify!(doc),
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

class _DocumentMobileCard extends StatelessWidget {
  const _DocumentMobileCard({
    required this.document,
    required this.selected,
    this.onTap,
    this.onVerify,
  });

  final StudentDocumentRecord document;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onVerify;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Semantics(
      label:
          '${document.studentName}, ${document.documentType.label}, ${document.status.label}',
      child: Material(
        color: selected ? colors.primaryContainer.withValues(alpha: 0.2) : colors.surface,
        borderRadius: BorderRadius.circular(AksharaSpacing.s3),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AksharaSpacing.s3),
          child: Padding(
            padding: const EdgeInsets.all(AksharaSpacing.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        document.studentName,
                        style: text.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    AdmissionsDocumentStatusChip(status: document.status),
                  ],
                ),
                Text(document.documentType.label),
                Text(
                  'Uploaded ${document.uploadedLabel}',
                  style: text.bodySmall.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                if (onVerify != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: onVerify,
                      child: const Text('Verify'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
