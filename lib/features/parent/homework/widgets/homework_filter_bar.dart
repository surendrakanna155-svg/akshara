import 'package:flutter/material.dart';

import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import '../homework_models.dart';

/// Horizontal filter chips for homework list status.
class HomeworkFilterBar extends StatelessWidget {
  const HomeworkFilterBar({
    super.key,
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  final HomeworkFilter selectedFilter;
  final ValueChanged<HomeworkFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    final colors = context.colors;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filter in HomeworkFilter.values) ...[
            FilterChip(
              label: Text(filter.label),
              selected: selectedFilter == filter,
              onSelected: (_) => onFilterChanged(filter),
              showCheckmark: false,
              labelStyle: text.labelMedium.copyWith(
                color: selectedFilter == filter
                    ? colors.onPrimaryContainer
                    : colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
              selectedColor: colors.primaryContainer,
              backgroundColor: colors.surface,
              side: BorderSide(color: colors.outlineVariant),
              // A11y-P1 tap target: `MaterialTapTargetSize.shrinkWrap` plus a
              // vertical density of -2 shrank this to roughly 24dp against
              // Flutter's 32dp `_kChipHeight`, on the primary filter row of a
              // high-frequency list screen. Both are removed: the theme's
              // `padded` default now wraps the chip in a >=48dp redirecting hit
              // target (`_ChipRedirectingHitDetectionWidget`), which is why the
              // vertical density had to go too — `padded` subtracts the density
              // adjustment from the 48dp minimum, so -2 would have capped the
              // target at 40dp. Horizontal compaction is kept.
              visualDensity: const VisualDensity(horizontal: -1),
            ),
            if (filter != HomeworkFilter.values.last)
              const SizedBox(width: AksharaSpacing.s2),
          ],
        ],
      ),
    );
  }
}
