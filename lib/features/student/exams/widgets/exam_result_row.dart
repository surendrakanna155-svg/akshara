import 'package:flutter/material.dart';

import '../../../../theme/radius.dart';
import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import '../exam_models.dart';

/// Past exam result row for ST-05.
class ExamResultRow extends StatelessWidget {
  const ExamResultRow({super.key, required this.result});

  final StudentExamResult result;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Semantics(
      container: true,
      label:
          '${result.title}, ${result.percent} percent, grade ${result.grade}',
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AksharaRadius.card,
          side: BorderSide(color: colors.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.title,
                      style: text.titleSmall.copyWith(color: colors.onSurface),
                    ),
                    const SizedBox(height: AksharaSpacing.s1),
                    Text(
                      '${result.termLabel} · ${result.dateLabel}',
                      style: text.bodySmall.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${result.scoreObtained}/${result.maxScore}',
                    style: text.titleSmall.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Grade ${result.grade}',
                    style: text.labelSmall.copyWith(color: colors.primary),
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
