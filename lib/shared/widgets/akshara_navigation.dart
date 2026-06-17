import 'package:flutter/material.dart';

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
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final bool expanded;
  final VoidCallback onTap;
  final bool semanticSelected;

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

/// Soft circular icon button for app bars (admin + mobile).
class AksharaAppBarIconButton extends StatelessWidget {
  const AksharaAppBarIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.child,
    this.size = 40,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
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

    if (tooltip == null) {
      return button;
    }

    return Tooltip(
      message: tooltip!,
      child: button,
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
