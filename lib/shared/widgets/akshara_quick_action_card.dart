import 'package:flutter/material.dart';

import '../../theme/motion.dart';
import '../../theme/radius.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';
import '../semantic_status.dart';
import 'akshara_interactive_surface.dart';

/// Quick action tile shared across teacher and student dashboards.
class AksharaQuickActionCard extends StatelessWidget {
  const AksharaQuickActionCard({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.semanticLabel,
    this.emphasis,
    this.minHeight = 104,
    this.labelFontWeight = FontWeight.normal,
    this.horizontalPadding = AksharaSpacing.s2,
    this.verticalPadding = AksharaSpacing.s3,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final StudentKpiTone? emphasis;
  final double minHeight;
  final FontWeight labelFontWeight;
  final double horizontalPadding;
  final double verticalPadding;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final effectiveMinHeight = minHeight * textScale.clamp(1, 2.25);

    final (iconBackground, iconColor, borderColor) = emphasis == null
        ? (
            colors.primaryContainer,
            colors.primary,
            colors.outlineVariant,
          )
        : () {
            final resolved = emphasis!.resolveQuickAction(context);
            return (
              resolved.container,
              resolved.foreground,
              resolved.border,
            );
          }();

    return Semantics(
      button: true,
      label: semanticLabel ?? label,
      enabled: onTap != null,
      child: AksharaInteractiveActivator(
        onActivate: onTap,
        enabled: onTap != null,
        child: AksharaInteractiveSurface(
          onTap: onTap,
          color: colors.surface,
          border: Border.all(color: borderColor),
          restingShadowLevel: AksharaMotion.restingShadow,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: effectiveMinHeight,
              minWidth: AksharaSpacing.minTouchTarget,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: verticalPadding,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: iconBackground,
                      borderRadius: AksharaRadius.chip,
                    ),
                    child: Icon(
                      icon,
                      size: 24,
                      color: iconColor,
                    ),
                  ),
                  const SizedBox(height: AksharaSpacing.s2),
                  Text(
                    label,
                    style: text.labelMedium.copyWith(
                      color: colors.onSurface,
                      fontWeight: labelFontWeight,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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

/// Responsive 2×2 (tablet) or 4-up row (mobile) quick action layout.
class AksharaQuickActionGrid extends StatelessWidget {
  const AksharaQuickActionGrid({
    super.key,
    required this.children,
    this.tabletBreakpoint = 768,
    this.mobileItemSpacing = AksharaSpacing.s2,
  });

  final List<Widget> children;
  final double tabletBreakpoint;
  final double mobileItemSpacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= tabletBreakpoint;
        final useTwoColumnGrid = isWide || children.length > 3;
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final baseAspect = isWide ? 1.35 : 1.5;
        final aspectRatio = baseAspect / textScale.clamp(1, 2.25);

        if (useTwoColumnGrid) {
          return GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AksharaSpacing.s3,
            crossAxisSpacing: AksharaSpacing.s3,
            childAspectRatio: aspectRatio,
            children: children,
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) SizedBox(width: mobileItemSpacing),
              Expanded(child: children[i]),
            ],
          ],
        );
      },
    );
  }
}

/// Two-up quick action row per ST-01 mobile layout.
class AksharaQuickActionRow extends StatelessWidget {
  const AksharaQuickActionRow({
    super.key,
    required this.children,
    this.largeMobileBreakpoint = 428,
    this.semanticLabel = 'Quick actions',
  });

  final List<Widget> children;
  final double largeMobileBreakpoint;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isLargeMobile =
            constraints.maxWidth >= largeMobileBreakpoint;
        final tileWidth = isLargeMobile ? 190.0 : 173.0;

        return Semantics(
          container: true,
          label: semanticLabel,
          child: Row(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(width: AksharaSpacing.s3),
                Expanded(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: tileWidth),
                    child: children[i],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
