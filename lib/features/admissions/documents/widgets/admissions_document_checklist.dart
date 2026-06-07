import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/security/permissions.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import '../../admissions_models.dart';
import '../../widgets/admissions_document_status_chip.dart';

/// Per-student document verification checklist for AD-06.
class AdmissionsDocumentChecklist extends ConsumerWidget {
  const AdmissionsDocumentChecklist({
    super.key,
    required this.items,
    this.onApprove,
    this.onReject,
  });

  final List<DocumentChecklistItem> items;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Semantics(
      container: true,
      label: 'Document checklist, ${items.length} document types',
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AksharaSpacing.s3),
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Verification checklist',
                style: text.titleSmall.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AksharaSpacing.s3),
              for (final item in items) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.documentType.label,
                            style: text.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            item.isRequired ? 'Required' : 'Optional',
                            style: text.bodySmall.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            item.note,
                            style: text.bodySmall.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AdmissionsDocumentStatusChip(status: item.status),
                  ],
                ),
                const Divider(height: AksharaSpacing.s6),
              ],
              if (onApprove != null || onReject != null)
                Row(
                  children: [
                    if (onApprove != null)
                      AksharaApproveAction(
                        permission: Permission.approveAdmissions,
                        child: FilledButton(
                          onPressed: onApprove,
                          child: const Text('Approve'),
                        ),
                      ),
                    const SizedBox(width: AksharaSpacing.s2),
                    if (onReject != null)
                      AksharaApproveAction(
                        permission: Permission.approveAdmissions,
                        child: OutlinedButton(
                          onPressed: onReject,
                          child: const Text('Reject'),
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
