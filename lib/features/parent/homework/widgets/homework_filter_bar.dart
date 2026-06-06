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
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: const VisualDensity(horizontal: -1, vertical: -2),
            ),
            if (filter != HomeworkFilter.values.last)
              const SizedBox(width: AksharaSpacing.s2),
          ],
        ],
      ),
    );
  }
}
