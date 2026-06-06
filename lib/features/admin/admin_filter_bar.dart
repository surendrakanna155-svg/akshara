import 'package:flutter/material.dart';

import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';

/// Shared filter row below the admin app bar (placeholder chips until modules ship).
class AdminFilterBar extends StatelessWidget {
  const AdminFilterBar({
    super.key,
    this.filters = const ['All', 'This period', 'Active'],
    this.selectedIndex = 0,
    this.onFilterSelected,
    this.trailing,
  });

  final List<String> filters;
  final int selectedIndex;
  final ValueChanged<int>? onFilterSelected;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Material(
      color: colors.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: colors.outlineVariant),
          ),
        ),
        child: SizedBox(
          height: AksharaSpacing.filterBarHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AksharaSpacing.s6),
            child: Row(
              children: [
                Icon(
                  Icons.filter_list,
                  size: 20,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(width: AksharaSpacing.s3),
                Expanded(
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: filters.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: AksharaSpacing.s2),
                    itemBuilder: (context, index) {
                      final selected = index == selectedIndex;
                      return FilterChip(
                        label: Text(filters[index]),
                        selected: selected,
                        showCheckmark: false,
                        onSelected: (_) => onFilterSelected?.call(index),
                      );
                    },
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: AksharaSpacing.s3),
                  trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
