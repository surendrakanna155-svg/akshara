import 'package:flutter/material.dart';

import '../../core/testing/qa_test_keys.dart';
import '../../shared/widgets/akshara_navigation.dart';
import '../../theme/radius.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';
import 'admin_layout.dart';

/// Shared filter row below the admin app bar (placeholder chips until modules ship).
///
/// On tablet/desktop this is an inline horizontal chip row. On phones the chips
/// collapse into a compact **"Filters" trigger** that opens a bottom sheet with
/// the options stacked for one-handed reach — same `filters`/`selectedIndex`/
/// `onFilterSelected` contract, just a mobile-friendly presentation.
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
    final isMobile = AdminLayout.isMobile(context);

    return Material(
      color: colors.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceContainerLowest,
          border: Border(
            bottom: BorderSide(
              color: colors.outlineVariant.withValues(alpha: 0.65),
            ),
          ),
        ),
        child: SizedBox(
          height: AksharaSpacing.filterBarHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AksharaSpacing.s6),
            child: Row(
              children: [
                if (isMobile)
                  Expanded(child: _MobileTrigger(
                    filters: filters,
                    selectedIndex: selectedIndex,
                    onFilterSelected: onFilterSelected,
                  ))
                else ...[
                  Icon(
                    Icons.tune_rounded,
                    size: 20,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: AksharaSpacing.s3),
                  Expanded(child: _InlineChips(
                    filters: filters,
                    selectedIndex: selectedIndex,
                    onFilterSelected: onFilterSelected,
                  )),
                ],
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

/// Tablet/desktop inline chip row (the original presentation).
class _InlineChips extends StatelessWidget {
  const _InlineChips({
    required this.filters,
    required this.selectedIndex,
    required this.onFilterSelected,
  });

  final List<String> filters;
  final int selectedIndex;
  final ValueChanged<int>? onFilterSelected;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: filters.length,
      separatorBuilder: (_, __) => const SizedBox(width: AksharaSpacing.s2),
      itemBuilder: (context, index) {
        return AksharaNavFilterChip(
          label: filters[index],
          selected: index == selectedIndex,
          onTap: () => onFilterSelected?.call(index),
        );
      },
    );
  }
}

/// Phone "Filters" trigger — shows the active filter and opens the option sheet.
class _MobileTrigger extends StatelessWidget {
  const _MobileTrigger({
    required this.filters,
    required this.selectedIndex,
    required this.onFilterSelected,
  });

  final List<String> filters;
  final int selectedIndex;
  final ValueChanged<int>? onFilterSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;
    final activeLabel = (selectedIndex >= 0 && selectedIndex < filters.length)
        ? filters[selectedIndex]
        : 'Filters';

    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        key: QaTestKeys.adminFilterTrigger,
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AksharaRadius.full),
          side: BorderSide(color: colors.outlineVariant),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AksharaRadius.full),
          onTap: () => _openSheet(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AksharaSpacing.s4,
              vertical: AksharaSpacing.s2,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.tune_rounded, size: 18, color: colors.primary),
                const SizedBox(width: AksharaSpacing.s2),
                Flexible(
                  child: Text(
                    activeLabel,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelLarge.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: AksharaSpacing.s1),
                Icon(Icons.expand_more_rounded,
                    size: 18, color: colors.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => _FilterSheet(
        filters: filters,
        selectedIndex: selectedIndex,
        onSelected: (index) {
          Navigator.of(sheetContext).pop();
          onFilterSelected?.call(index);
        },
      ),
    );
  }
}

/// Bottom-sheet body listing the filter options, current one checked.
class _FilterSheet extends StatelessWidget {
  const _FilterSheet({
    required this.filters,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> filters;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return SafeArea(
      child: SingleChildScrollView(
        key: QaTestKeys.adminFilterSheet,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AksharaSpacing.s5,
            AksharaSpacing.s2,
            AksharaSpacing.s5,
            AksharaSpacing.s5,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Filters',
                style: text.titleLarge.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AksharaSpacing.s3),
              for (var index = 0; index < filters.length; index++)
                ListTile(
                  key: QaTestKeys.adminFilterSheetOption(filters[index]),
                  contentPadding: EdgeInsets.zero,
                  title: Text(filters[index], style: text.bodyLarge),
                  trailing: index == selectedIndex
                      ? Icon(Icons.check_rounded, color: colors.primary)
                      : null,
                  onTap: () => onSelected(index),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
