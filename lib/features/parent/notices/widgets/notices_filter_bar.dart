import 'package:flutter/material.dart';

import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import '../notices_models.dart';

/// Horizontal category filter chips for PA-07 notices.
class NoticesFilterBar extends StatelessWidget {
  const NoticesFilterBar({
    super.key,
    required this.selectedCategory,
    required this.onCategoryChanged,
  });

  final NoticeCategory selectedCategory;
  final ValueChanged<NoticeCategory> onCategoryChanged;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    final colors = context.colors;

    return Semantics(
      container: true,
      label: 'Notice category filters',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final category in NoticeCategory.values) ...[
              FilterChip(
                label: Text(category.label),
                selected: selectedCategory == category,
                onSelected: (_) => onCategoryChanged(category),
                showCheckmark: false,
                labelStyle: text.labelMedium.copyWith(
                  color: selectedCategory == category
                      ? colors.onPrimaryContainer
                      : colors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
                selectedColor: colors.primaryContainer,
                backgroundColor: colors.surface,
                side: BorderSide(color: colors.outlineVariant),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: const VisualDensity(horizontal: -1, vertical: -2),
              ),
              if (category != NoticeCategory.values.last)
                const SizedBox(width: AksharaSpacing.s2),
            ],
          ],
        ),
      ),
    );
  }
}
