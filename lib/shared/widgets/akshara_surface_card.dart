import 'package:flutter/material.dart';

import '../../theme/motion.dart';
import '../../theme/radius.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';
import 'akshara_interactive_surface.dart';

/// Standard elevated surface card for dashboards and list rows.
class AksharaSurfaceCard extends StatelessWidget {
  const AksharaSurfaceCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AksharaSpacing.s4),
    this.margin,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final card = AksharaInteractiveSurface(
      onTap: onTap,
      semanticLabel: semanticLabel,
      color: colors.surface,
      border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.75)),
      restingShadowLevel: onTap == null ? 0 : AksharaMotion.restingShadow,
      child: Padding(padding: padding, child: child),
    );

    return margin == null ? card : Padding(padding: margin!, child: card);
  }
}

/// Premium feature tile — a tappable surface card with an accent-tinted rounded
/// icon badge, a title + subtitle, and a soft chevron. DS V2 P3: the flat bare
/// icon is replaced by the accent badge so navigation tiles read in the same
/// premium visual language as KPI cards. An optional [accent] tints the badge
/// (defaults to the theme primary / persona accent).
class AksharaSurfaceListTile extends StatelessWidget {
  const AksharaSurfaceListTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.accent,
    this.semanticLabel,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// Semantic accent for the icon badge; null → theme primary.
  final KpiAccent? accent;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;
    final (badgeBg, badgeFg) = accent == null
        ? (colors.primaryContainer, colors.primary)
        : (() {
            final a = accent!.resolve(context);
            return (a.container, a.foreground);
          }());

    return AksharaSurfaceCard(
      onTap: onTap,
      semanticLabel: semanticLabel ?? title,
      padding: const EdgeInsets.symmetric(
        horizontal: AksharaSpacing.s4,
        vertical: AksharaSpacing.s3,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(AksharaRadius.md),
            ),
            child: Icon(icon, size: 22, color: badgeFg),
          ),
          const SizedBox(width: AksharaSpacing.s4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: text.bodyLarge.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: text.bodySmall.copyWith(color: colors.onSurfaceVariant),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AksharaSpacing.s2),
          Icon(Icons.chevron_right, size: 20, color: colors.onSurfaceVariant),
        ],
      ),
    );
  }
}
