import 'package:flutter/material.dart';

import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import '../receipt_models.dart';

/// Category filter chips for PA-11 receipts list.
class ReceiptFilterBar extends StatelessWidget {
  const ReceiptFilterBar({
    super.key,
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  final ReceiptFilter selectedFilter;
  final ValueChanged<ReceiptFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    final colors = context.colors;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filter in ReceiptFilter.values) ...[
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
              // A11y-P1 tap target: `shrinkWrap` + a vertical density of -2 gave
              // roughly a 24dp target. The theme's `padded` default now wraps
              // the chip in a >=48dp redirecting hit target; the vertical
              // density had to go with it because `padded` subtracts the density
              // adjustment from that 48dp minimum. Horizontal compaction kept.
              visualDensity: const VisualDensity(horizontal: -1),
            ),
            if (filter != ReceiptFilter.values.last)
              const SizedBox(width: AksharaSpacing.s2),
          ],
        ],
      ),
    );
  }
}
