import 'package:flutter/material.dart';

import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import '../../admissions_models.dart';

/// Pipeline status progression stepper for AD-04.
class AdmissionsLeadStatusProgression extends StatelessWidget {
  const AdmissionsLeadStatusProgression({
    super.key,
    required this.steps,
  });

  final List<LeadStatusStep> steps;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Semantics(
      container: true,
      label: 'Lead status progression, ${steps.length} stages',
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AksharaSpacing.s3),
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Status progression',
                style: text.titleSmall.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AksharaSpacing.s3),
              ...steps.map((step) {
                final icon = step.isComplete
                    ? Icons.check_circle
                    : step.isCurrent
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off;
                final iconColor = step.isComplete
                    ? colors.primary
                    : step.isCurrent
                        ? colors.tertiary
                        : colors.onSurfaceVariant;

                return Padding(
                  padding: const EdgeInsets.only(bottom: AksharaSpacing.s2),
                  child: Row(
                    children: [
                      Icon(icon, size: 18, color: iconColor),
                      const SizedBox(width: AksharaSpacing.s2),
                      Expanded(
                        child: Text(
                          step.stage.label,
                          style: text.bodyMedium.copyWith(
                            fontWeight: step.isCurrent
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: step.isCurrent
                                ? colors.onSurface
                                : colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
