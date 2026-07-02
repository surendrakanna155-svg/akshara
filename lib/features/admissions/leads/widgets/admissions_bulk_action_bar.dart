import 'package:flutter/material.dart';

import '../../../../core/testing/qa_test_keys.dart';
import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';

/// ADM-3: contextual bar shown when one or more leads are ticked. Offers the two
/// bulk actions the backend supports — assign a counselor and change the stage —
/// plus a clear-selection affordance.
class AdmissionsBulkActionBar extends StatelessWidget {
  const AdmissionsBulkActionBar({
    super.key,
    required this.selectedCount,
    required this.onAssign,
    required this.onChangeStage,
    required this.onClear,
  });

  final int selectedCount;
  final VoidCallback onAssign;
  final VoidCallback onChangeStage;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      container: true,
      label: '$selectedCount leads selected for bulk action',
      child: Material(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(AksharaSpacing.s2),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AksharaSpacing.s4,
            vertical: AksharaSpacing.s2,
          ),
          child: Wrap(
            spacing: AksharaSpacing.s2,
            runSpacing: AksharaSpacing.s2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '$selectedCount selected',
                style: context.aksharaText.labelLarge.copyWith(
                  color: colors.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
              FilledButton.icon(
                key: QaTestKeys.admissionsBulkAssignButton,
                onPressed: onAssign,
                icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                label: const Text('Assign counselor'),
              ),
              FilledButton.tonalIcon(
                key: QaTestKeys.admissionsBulkStageButton,
                onPressed: onChangeStage,
                icon: const Icon(Icons.swap_horiz, size: 18),
                label: const Text('Change stage'),
              ),
              TextButton(
                onPressed: onClear,
                child: const Text('Clear'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
