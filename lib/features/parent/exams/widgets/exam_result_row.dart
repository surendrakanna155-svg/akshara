import 'package:flutter/material.dart';

import '../../../../theme/radius.dart';
import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import '../exam_models.dart';

/// Parent exams result row item.
class ExamResultRow extends StatelessWidget {
  const ExamResultRow({
    super.key,
    required this.item,
    this.onTap,
    this.showDivider = true,
  });

  final ExamResultItem item;
  final VoidCallback? onTap;
  final bool showDivider;

  static const double rowHeight = 76;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;
    final ext = context.akshara;
    final accent = switch (item.percent) {
      >= 85 => (ext.successContainer, ext.success, Icons.trending_up),
      >= 60 => (ext.warningContainer, ext.warning, Icons.trending_flat),
      _ => (colors.errorContainer, colors.error, Icons.trending_down),
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: onTap != null,
          label:
              '${item.title}, ${item.termLabel}, ${item.scoreObtained}/${item.maxScore}, grade ${item.grade}',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: SizedBox(
                height: rowHeight,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AksharaSpacing.s4),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: accent.$1,
                          borderRadius: AksharaRadius.chip,
                        ),
                        child: Icon(accent.$3, size: 20, color: accent.$2),
                      ),
                      const SizedBox(width: AksharaSpacing.s3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              item.title,
                              style: text.bodyMedium.copyWith(
                                color: colors.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${item.termLabel} · ${item.dateLabel}',
                              style: text.bodySmall.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (item.remarks != null)
                              Text(
                                item.remarks!,
                                style: text.labelSmall.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AksharaSpacing.s2),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${item.scoreObtained}/${item.maxScore}',
                            style: text.titleSmall
                                .copyWith(color: colors.onSurface),
                          ),
                          Text(
                            '${item.percent}% · ${item.grade}',
                            style: text.labelSmall.copyWith(color: accent.$2),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            color: colors.outlineVariant,
          ),
      ],
    );
  }
}
