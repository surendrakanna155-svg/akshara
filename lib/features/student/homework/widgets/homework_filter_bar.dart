import 'package:flutter/material.dart';

import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import '../homework_models.dart';

/// Filter chips for ST-04 homework list.
class HomeworkFilterBar extends StatelessWidget {
  const HomeworkFilterBar({
    super.key,
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  final StudentHomeworkFilter selectedFilter;
  final ValueChanged<StudentHomeworkFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    final colors = context.colors;

    return Semantics(
      container: true,
      label: 'Homework filters',
      child: Row(
        children: [
          for (final filter in StudentHomeworkFilter.values) ...[
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
            ),
            if (filter != StudentHomeworkFilter.values.last)
              const SizedBox(width: AksharaSpacing.s2),
          ],
        ],
      ),
    );
  }
}
