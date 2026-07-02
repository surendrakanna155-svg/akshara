import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/security/permissions.dart';
import '../../../../core/testing/qa_test_keys.dart';
import '../../../../shared/widgets/akshara_status_chip.dart';
import '../../../../shared/widgets/akshara_manage_action.dart';
import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import '../../admissions_models.dart';

/// Fee handoff configuration panel for an approved student (AD-08).
class AdmissionsFeeHandoffPanel extends ConsumerWidget {
  const AdmissionsFeeHandoffPanel({
    super.key,
    required this.handoff,
    required this.feeStructures,
    this.onFeeStructureChanged,
    this.onSendToFinance,
    this.onGenerateOfferLetter,
  });

  final ApprovedStudentHandoff handoff;
  final List<FeeStructureOption> feeStructures;
  final ValueChanged<String>? onFeeStructureChanged;
  final VoidCallback? onSendToFinance;

  /// ADM-D4: generate + print/share the offer letter for this approved
  /// enrollment. Null (or no enrollment id) hides the action.
  final VoidCallback? onGenerateOfferLetter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = context.aksharaText;
    final statusTone = switch (handoff.handoffStatus) {
      FeeHandoffStatus.pending => KpiAccent.warning,
      FeeHandoffStatus.sentToFinance => KpiAccent.primary,
      FeeHandoffStatus.completed => KpiAccent.success,
      FeeHandoffStatus.failed => KpiAccent.error,
    };

    return Semantics(
      container: true,
      label: 'Fee handoff for ${handoff.studentName}',
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AksharaSpacing.s3),
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                handoff.studentName,
                style: text.titleMedium.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                '${handoff.applicationId} · Class ${handoff.classLabel}',
                style: text.bodySmall.copyWith(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: AksharaSpacing.s3),
              AksharaStatusChip(
                label: handoff.handoffStatus.name,
                tone: statusTone,
              ),
              const SizedBox(height: AksharaSpacing.s4),
              _PreviewTile(
                label: 'Admission number',
                value: handoff.admissionNumber,
              ),
              _PreviewTile(
                label: 'Preview student ID',
                value: handoff.previewStudentId,
              ),
              _PreviewTile(
                label: 'SIS handoff',
                value: handoff.sisHandoffLabel,
              ),
              const SizedBox(height: AksharaSpacing.s3),
              DropdownMenu<String>(
                initialSelection: handoff.selectedFeeStructureId,
                label: const Text('Fee structure'),
                dropdownMenuEntries: [
                  for (final fee in feeStructures)
                    DropdownMenuEntry(
                      value: fee.id,
                      label: '${fee.label} · ${fee.annualAmount}',
                    ),
                ],
                onSelected: onFeeStructureChanged == null
                    ? null
                    : (value) {
                        if (value != null) onFeeStructureChanged!(value);
                      },
              ),
              const SizedBox(height: AksharaSpacing.s3),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Transport required'),
                value: handoff.needsTransport,
                onChanged: null,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Hostel required'),
                value: handoff.needsHostel,
                onChanged: null,
              ),
              const SizedBox(height: AksharaSpacing.s3),
              AksharaManageAction(
                permission: Permission.manageAdmissions,
                child: FilledButton(
                  onPressed: onSendToFinance,
                  child: const Text('Send to Finance'),
                ),
              ),
              // ADM-D4: offer letter for the approved enrollment (read + client
              // PDF). Shown only when the handoff resolves to an enrollment.
              if (onGenerateOfferLetter != null &&
                  handoff.enrollmentId != null &&
                  handoff.enrollmentId!.isNotEmpty) ...[
                const SizedBox(height: AksharaSpacing.s2),
                OutlinedButton.icon(
                  key: QaTestKeys.admissionsOfferLetterButton,
                  onPressed: onGenerateOfferLetter,
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                  label: const Text('Offer letter'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewTile extends StatelessWidget {
  const _PreviewTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AksharaSpacing.s2),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: context.aksharaText.bodySmall.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
