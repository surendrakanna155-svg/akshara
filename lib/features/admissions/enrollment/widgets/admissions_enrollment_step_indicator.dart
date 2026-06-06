import 'package:flutter/material.dart';

import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import '../../admissions_models.dart';

/// Wizard step indicator for AD-05 enrollment.
class AdmissionsEnrollmentStepIndicator extends StatelessWidget {
  const AdmissionsEnrollmentStepIndicator({
    super.key,
    required this.currentStep,
  });

  final EnrollmentStep currentStep;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;
    final steps = EnrollmentStep.values;
    final currentIndex = steps.indexOf(currentStep);

    return Semantics(
      container: true,
      label:
          'Enrollment step ${currentIndex + 1} of ${steps.length}: ${currentStep.label}',
      child: Row(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            Expanded(
              child: Column(
                children: [
                  Row(
                    children: [
                      if (i > 0)
                        Expanded(
                          child: Container(
                            height: 2,
                            color: i <= currentIndex
                                ? colors.primary
                                : colors.outlineVariant,
                          ),
                        ),
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: i <= currentIndex
                            ? colors.primary
                            : colors.surfaceContainerHighest,
                        child: Text(
                          '${i + 1}',
                          style: text.labelSmall.copyWith(
                            color: i <= currentIndex
                                ? colors.onPrimary
                                : colors.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (i < steps.length - 1)
                        Expanded(
                          child: Container(
                            height: 2,
                            color: i < currentIndex
                                ? colors.primary
                                : colors.outlineVariant,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AksharaSpacing.s1),
                  Text(
                    steps[i].label,
                    style: text.labelSmall.copyWith(
                      color: i == currentIndex
                          ? colors.primary
                          : colors.onSurfaceVariant,
                      fontWeight:
                          i == currentIndex ? FontWeight.w600 : FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
