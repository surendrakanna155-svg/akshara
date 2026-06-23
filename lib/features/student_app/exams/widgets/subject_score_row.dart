import 'package:flutter/material.dart';

import '../../../../shared/widgets/akshara_status_chip.dart';
import '../../../../theme/radius.dart';
import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import '../exam_models.dart';

/// Subject-wise score row for ST-05 results summary.
class SubjectScoreRow extends StatelessWidget {
  const SubjectScoreRow({super.key, required this.score});

  final SubjectScore score;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;
    final ext = context.akshara;

    return Semantics(
      label: '${score.subject}, ${score.scorePercent} percent, grade ${score.grade}',
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AksharaRadius.card,
          side: BorderSide(color: colors.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AksharaSpacing.s4,
            vertical: AksharaSpacing.s3,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  score.subject,
                  style: text.bodyMedium.copyWith(color: colors.onSurface),
                ),
              ),
              Text(
                '${score.scorePercent}%',
                style: text.titleSmall.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: AksharaSpacing.s2),
              AksharaStatusChip(
                label: score.grade,
                background: ext.successContainer,
                foreground: ext.success,
                size: AksharaStatusChipSize.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
