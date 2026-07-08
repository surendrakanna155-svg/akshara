import 'package:flutter/material.dart';

import '../../core/testing/qa_test_keys.dart';
import '../../theme/breakpoints.dart';
import '../../theme/motion.dart';
import '../../theme/radius.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';

/// Brand header for ERP navigation rail and drawer.
class AksharaNavBrandHeader extends StatelessWidget {
  const AksharaNavBrandHeader({
    super.key,
    this.compact = false,
    this.padding = const EdgeInsets.fromLTRB(
      AksharaSpacing.s4,
      AksharaSpacing.s6,
      AksharaSpacing.s4,
      AksharaSpacing.s4,
    ),
  });

  final bool compact;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Padding(
      padding: padding,
      child: compact
          ? Icon(Icons.school_rounded, color: colors.primary, size: 28)
          : Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: AksharaRadius.chip,
                  ),
                  child: Icon(
                    Icons.school_rounded,
                    color: colors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AksharaSpacing.s3),
                Expanded(
                  child: Text(
                    'Akshara ERP',
                    style: text.titleSmall.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
    );
  }
}

/// Premium navigation rail / drawer destination tile.
class AksharaNavRailTile extends StatelessWidget {
  const AksharaNavRailTile({
    super.key,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onTap,
    this.expanded = true,
    this.semanticSelected = false,
    this.locked = false,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final bool expanded;
  final VoidCallback onTap;
  final bool semanticSelected;

  /// Module is visible but locked by the org's plan (B2) — shows a lock glyph.
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;
    final iconData = selected ? selectedIcon : icon;

    return Semantics(
      selected: semanticSelected || selected,
      button: true,
      label: label,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: expanded ? AksharaSpacing.s3 : AksharaSpacing.s2,
          vertical: AksharaSpacing.s1,
        ),
        child: Material(
          color: selected
              ? colors.primaryContainer.withValues(alpha: 0.55)
              : Colors.transparent,
          borderRadius: AksharaRadius.chip,
          child: InkWell(
            onTap: onTap,
            borderRadius: AksharaRadius.chip,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: AksharaRadius.chip,
                border: selected
                    ? Border.all(
                        color: colors.primary.withValues(alpha: 0.22),
                      )
                    : null,
              ),
              padding: EdgeInsets.symmetric(
                horizontal: expanded ? AksharaSpacing.s3 : AksharaSpacing.s2,
                vertical: AksharaSpacing.s3,
              ),
              child: expanded
                  ? Row(
                      children: [
                        if (selected)
                          Container(
                            width: 3,
                            height: 22,
                            margin: const EdgeInsets.only(right: AksharaSpacing.s2),
                            decoration: BoxDecoration(
                              color: colors.primary,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        Icon(
                          iconData,
                          size: 22,
                          color: selected
                              ? colors.primary
                              : colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: AksharaSpacing.s3),
                        Expanded(
                          child: Text(
                            label,
                            style: text.labelLarge.copyWith(
                              color: selected
                                  ? colors.primary
                                  : colors.onSurface,
                              fontWeight:
                                  selected ? FontWeight.w600 : FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (locked)
                          Icon(
                            Icons.lock_outline,
                            size: 16,
                            color: colors.onSurfaceVariant,
                          ),
                      ],
                    )
                  : Center(
                      child: Icon(
                        iconData,
                        size: 22,
                        color: selected
                            ? colors.primary
                            : colors.onSurfaceVariant,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontal module sub-navigation tab (Finance, HR, Admissions, etc.).
class AksharaModuleSubNavTab extends StatelessWidget {
  const AksharaModuleSubNavTab({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Semantics(
      button: true,
      selected: selected,
      label: '$label tab',
      child: AnimatedContainer(
        duration: AksharaMotion.fast,
        curve: AksharaMotion.emphasis,
        decoration: BoxDecoration(
          color: selected
              ? colors.primaryContainer.withValues(alpha: 0.65)
              : colors.surfaceContainerLow,
          borderRadius: AksharaRadius.chip,
          border: Border.all(
            color: selected
                ? colors.primary.withValues(alpha: 0.45)
                : colors.outlineVariant.withValues(alpha: 0.65),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: AksharaRadius.chip,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AksharaSpacing.s4,
                vertical: AksharaSpacing.s2,
              ),
              child: Text(
                label,
                style: text.labelLarge.copyWith(
                  color: selected ? colors.primary : colors.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One entry in an [AksharaModuleSubNav]. Carries its own optional [itemKey]
/// (the per-module QA key) so migrating the hand-rolled strips keeps their keys.
class AksharaModuleSubNavItem {
  const AksharaModuleSubNavItem({
    required this.label,
    required this.selected,
    required this.onTap,
    this.itemKey,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Key? itemKey;
}

/// Responsive module sub-navigation.
///
/// On tablet+ it renders the familiar horizontal scrolling tab strip. On a
/// phone it shows at most [maxInlineOnMobile] tabs (always including the
/// selected screen) and folds the rest into a premium "More" bottom sheet —
/// closing MOBILE_FIRST_AUDIT #3 (sub-nav strips running off-screen with no
/// scroll cue). One widget so all 12 module sub-navs can't drift apart.
class AksharaModuleSubNav extends StatelessWidget {
  const AksharaModuleSubNav({
    super.key,
    required this.moduleKey,
    required this.semanticsLabel,
    required this.items,
    this.maxInlineOnMobile = 4,
  });

  /// Stable module slug (e.g. 'finance') used for the overflow QA keys.
  final String moduleKey;
  final String semanticsLabel;
  final List<AksharaModuleSubNavItem> items;
  final int maxInlineOnMobile;

  @override
  Widget build(BuildContext context) {
    final isMobile =
        AksharaBreakpoints.isMobile(MediaQuery.sizeOf(context).width);

    // Desktop / tablet (or a short list): the familiar scrolling strip.
    if (!isMobile || items.length <= maxInlineOnMobile + 1) {
      return Semantics(
        container: true,
        label: semanticsLabel,
        child: _tabRow(items, scrollable: true),
      );
    }

    // Phone: keep the selected screen visible, overflow the rest.
    final inline = items.take(maxInlineOnMobile).toList();
    var overflow = items.skip(maxInlineOnMobile).toList();
    final selectedIndex = items.indexWhere((e) => e.selected);
    if (selectedIndex >= maxInlineOnMobile) {
      final selected = items[selectedIndex];
      final displaced = inline[maxInlineOnMobile - 1];
      inline[maxInlineOnMobile - 1] = selected;
      overflow = [
        displaced,
        for (final e in items.skip(maxInlineOnMobile))
          if (!identical(e, selected)) e,
      ];
    }

    // Inline tabs scroll inside the available space; the "More" affordance is
    // pinned so it never scrolls off-screen (the bug being fixed).
    return Semantics(
      container: true,
      label: semanticsLabel,
      child: Row(
        children: [
          Expanded(child: _tabRow(inline, scrollable: true)),
          const SizedBox(width: AksharaSpacing.s2),
          _MoreSubNavTab(
            key: QaTestKeys.moduleSubNavMore(moduleKey),
            onTap: () => _openMoreSheet(context, overflow),
          ),
        ],
      ),
    );
  }

  Widget _tabRow(
    List<AksharaModuleSubNavItem> tabs, {
    required bool scrollable,
  }) {
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final item in tabs) ...[
          AksharaModuleSubNavTab(
            key: item.itemKey,
            label: item.label,
            selected: item.selected,
            onTap: item.onTap,
          ),
          if (item != tabs.last) const SizedBox(width: AksharaSpacing.s2),
        ],
      ],
    );
    if (!scrollable) return row;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: row,
    );
  }

  void _openMoreSheet(
    BuildContext context,
    List<AksharaModuleSubNavItem> more,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final colors = sheetContext.colors;
        final text = sheetContext.aksharaText;
        return SafeArea(
          child: SingleChildScrollView(
            key: QaTestKeys.moduleSubNavSheet(moduleKey),
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
                    semanticsLabel,
                    style:
                        text.titleMedium.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: AksharaSpacing.s3),
                  for (final item in more)
                    ListTile(
                      key: item.itemKey,
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.label),
                      selected: item.selected,
                      selectedColor: colors.primary,
                      trailing: item.selected
                          ? Icon(Icons.check, color: colors.primary)
                          : null,
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        item.onTap();
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The "More" chip rendered at the tail of a collapsed [AksharaModuleSubNav].
class _MoreSubNavTab extends StatelessWidget {
  const _MoreSubNavTab({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Semantics(
      button: true,
      label: 'More screens',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: AksharaRadius.chip,
          border: Border.all(
            color: colors.outlineVariant.withValues(alpha: 0.65),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: AksharaRadius.chip,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AksharaSpacing.s4,
                vertical: AksharaSpacing.s2,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'More',
                    style: text.labelLarge.copyWith(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Icon(
                    Icons.expand_more_rounded,
                    size: 18,
                    color: colors.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Soft circular icon button for app bars (admin + mobile).
class AksharaAppBarIconButton extends StatelessWidget {
  const AksharaAppBarIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.semanticLabel,
    this.child,
    this.size = 40,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  /// Accessible name announced to screen readers. Falls back to [tooltip];
  /// give it explicitly when the icon carries a badge (so the count doesn't
  /// leak into the label) or when there is no tooltip.
  final String? semanticLabel;
  final Widget? child;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final button = Material(
      color: colors.surfaceContainerLow,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: size,
          height: size,
          child: Center(
            child: child ?? Icon(icon, size: 22, color: colors.onSurfaceVariant),
          ),
        ),
      ),
    );

    // An icon-only button has no text child, so without an explicit name it
    // announces as an unlabeled button. Give it the tooltip (or override) as
    // its accessible name — a no-op visually.
    final label = semanticLabel ?? tooltip;
    final labelled = label == null
        ? button
        : Semantics(button: true, label: label, child: button);

    if (tooltip == null) {
      return labelled;
    }

    return Tooltip(
      message: tooltip!,
      child: labelled,
    );
  }
}

/// Segmented filter chip for admin filter bars.
class AksharaNavFilterChip extends StatelessWidget {
  const AksharaNavFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Material(
      color: selected ? colors.primaryContainer : colors.surface,
      borderRadius: AksharaRadius.chip,
      child: InkWell(
        onTap: onTap,
        borderRadius: AksharaRadius.chip,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AksharaSpacing.s3,
            vertical: AksharaSpacing.s2,
          ),
          decoration: BoxDecoration(
            borderRadius: AksharaRadius.chip,
            border: Border.all(
              color: selected
                  ? colors.primary.withValues(alpha: 0.45)
                  : colors.outlineVariant.withValues(alpha: 0.65),
            ),
          ),
          child: Text(
            label,
            style: text.labelMedium.copyWith(
              color: selected ? colors.onPrimaryContainer : colors.onSurfaceVariant,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

/// Premium search field shell for admin app bar.
class AksharaNavSearchField extends StatelessWidget {
  const AksharaNavSearchField({
    super.key,
    required this.hint,
    this.onTap,
    this.width = 280,
  });

  final String hint;
  final VoidCallback? onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Semantics(
      button: true,
      label: hint,
      child: InkWell(
        onTap: onTap,
        borderRadius: AksharaRadius.inputBorder,
        child: Container(
          width: width,
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: AksharaSpacing.s3),
          decoration: BoxDecoration(
            color: colors.surfaceContainerLow,
            borderRadius: AksharaRadius.inputBorder,
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: 0.75),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.search, size: 20, color: colors.onSurfaceVariant),
              const SizedBox(width: AksharaSpacing.s2),
              Expanded(
                child: Text(
                  hint,
                  style: text.bodySmall.copyWith(color: colors.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.keyboard_command_key,
                size: 14,
                color: colors.onSurfaceVariant.withValues(alpha: 0.55),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
