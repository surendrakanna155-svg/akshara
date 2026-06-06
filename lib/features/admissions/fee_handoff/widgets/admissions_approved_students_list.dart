import 'package:flutter/material.dart';

import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import '../../admissions_models.dart';

/// Approved students list for fee handoff selection (AD-08).
class AdmissionsApprovedStudentsList extends StatelessWidget {
  const AdmissionsApprovedStudentsList({
    super.key,
    required this.handoffs,
    this.selectedId,
    this.onSelect,
  });

  final List<ApprovedStudentHandoff> handoffs;
  final String? selectedId;
  final ValueChanged<ApprovedStudentHandoff>? onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      container: true,
      label: 'Approved students, ${handoffs.length} records',
      child: Column(
        children: [
          for (final handoff in handoffs)
            Padding(
              padding: const EdgeInsets.only(bottom: AksharaSpacing.s2),
              child: Material(
                color: handoff.id == selectedId
                    ? colors.primaryContainer.withValues(alpha: 0.3)
                    : colors.surface,
                borderRadius: BorderRadius.circular(AksharaSpacing.s3),
                child: ListTile(
                  selected: handoff.id == selectedId,
                  title: Text(handoff.studentName),
                  subtitle: Text(
                    '${handoff.admissionNumber} · ${handoff.handoffStatus.name}',
                  ),
                  onTap:
                      onSelect == null ? null : () => onSelect!(handoff),
                  trailing: Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
