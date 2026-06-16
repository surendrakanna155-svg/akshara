import 'package:flutter/material.dart';

import '../../theme/radius.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';

/// Layout variants for [AksharaKpiCard].
enum AksharaKpiCardStyle {
  /// PA-02 bordered strip tile with icon box (88px).
  strip,

  /// TA-01 filled accent container tiles.
  filled,

  /// ST-01 status row with icon, label, and detail.
  status,

  /// ST-01 homework count tile.
  count,
}

/// Compact KPI metric card used across parent, teacher, and student dashboards.
class AksharaKpiCard extends StatelessWidget {
  const AksharaKpiCard({
    super.key,
    required this.value,
    required this.subtitle,
    required this.accent,
    this.icon,
    this.onTap,
    this.semanticLabel,
    this.style = AksharaKpiCardStyle.strip,
    this.detail,
    this.height = 88,
    this.drillKey,
  });

  final String value;
  final String subtitle;
  final KpiAccent accent;
  final IconData? icon;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final AksharaKpiCardStyle style;
  final String? detail;
  final double height;
  /// QA / Patrol tap target — placed on the hit-testable surface.
  final Key? drillKey;

  static const double iconBoxSize = 32;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: semanticLabel ?? '$value $subtitle',
      child: switch (style) {
        AksharaKpiCardStyle.strip => _StripKpiCard(
            value: value,
            subtitle: subtitle,
            accent: accent,
            icon: icon,
            onTap: onTap,
          ),
        AksharaKpiCardStyle.filled => _FilledKpiTile(
            drillKey: drillKey,
            value: value,
            label: subtitle,
            accent: accent,
            icon: icon,
            onTap: onTap,
          ),
        AksharaKpiCardStyle.status => _StatusKpiCard(
            value: value,
            label: subtitle,
            detail: detail ?? '',
            accent: accent,
            icon: icon ?? Icons.fact_check_outlined,
            height: height,
            onTap: onTap,
          ),
        AksharaKpiCardStyle.count => _CountKpiCard(
            count: int.tryParse(value) ?? 0,
            label: subtitle,
            detail: detail ?? 'Tap to view all',
            accent: accent,
            icon: icon ?? Icons.assignment_outlined,
            height: height,
            onTap: onTap,
          ),
      },
    );
  }
}

class _StripKpiCard extends StatelessWidget {
  const _StripKpiCard({
    required this.value,
    required this.subtitle,
    required this.accent,
    this.icon,
    this.onTap,
  });

  final String value;
  final String subtitle;
  final KpiAccent accent;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;
    final accentColors = accent.resolve(context);
    final resolvedIcon = icon ?? _defaultIcon(accent);

    return Material(
      color: colors.surface,
      elevation: 1,
      shadowColor: colors.onSurface.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: AksharaRadius.card,
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: AksharaRadius.card,
        child: SizedBox(
          height: 88,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AksharaSpacing.s3,
              vertical: AksharaSpacing.s2,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: AksharaKpiCard.iconBoxSize,
                  height: AksharaKpiCard.iconBoxSize,
                  decoration: BoxDecoration(
                    color: accentColors.container,
                    borderRadius: AksharaRadius.chip,
                  ),
                  child: Icon(
                    resolvedIcon,
                    size: 18,
                    color: accentColors.foreground,
                  ),
                ),
                const SizedBox(height: AksharaSpacing.s1),
                Text(
                  value,
                  style: text.titleSmall.copyWith(color: colors.onSurface),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: text.bodySmall.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _defaultIcon(KpiAccent accent) {
    return switch (accent) {
      KpiAccent.success => Icons.check_circle_outline,
      KpiAccent.error => Icons.cancel_outlined,
      KpiAccent.warning => Icons.schedule,
      KpiAccent.primary => Icons.insights_outlined,
      KpiAccent.neutral => Icons.analytics_outlined,
    };
  }
}

class _FilledKpiTile extends StatelessWidget {
  const _FilledKpiTile({
    this.drillKey,
    required this.value,
    required this.label,
    required this.accent,
    this.icon,
    this.onTap,
  });

  final Key? drillKey;

  final String value;
  final String label;
  final KpiAccent accent;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;
    final accentColors = accent.resolve(context);

    return Material(
      key: drillKey,
      color: accentColors.container,
      elevation: onTap != null ? 1 : 0,
      shadowColor: colors.onSurface.withValues(alpha: 0.06),
      borderRadius: AksharaRadius.card,
      child: InkWell(
        onTap: onTap,
        borderRadius: AksharaRadius.card,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.hasBoundedHeight &&
                constraints.maxHeight < 120;
            final padding = compact
                ? const EdgeInsets.symmetric(
                    horizontal: AksharaSpacing.s3,
                    vertical: AksharaSpacing.s2,
                  )
                : const EdgeInsets.all(AksharaSpacing.s4);
            final valueStyle = (compact ? text.titleSmall : text.titleLarge)
                .copyWith(
              color: accentColors.foreground,
              fontWeight: FontWeight.w700,
              height: 1.1,
            );
            final labelStyle = (compact ? text.labelSmall : text.labelMedium)
                .copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            );
            final iconSize = compact ? 16.0 : 20.0;

            return Padding(
              padding: padding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: iconSize, color: accentColors.foreground),
                        SizedBox(width: compact ? AksharaSpacing.s1 : AksharaSpacing.s2),
                      ],
                      Expanded(
                        child: Text(
                          value,
                          style: valueStyle,
                          maxLines: compact ? 1 : 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (onTap != null && !compact)
                        Icon(
                          Icons.chevron_right,
                          size: 20,
                          color: colors.onSurfaceVariant,
                        ),
                    ],
                  ),
                  SizedBox(
                    height: compact ? AksharaSpacing.s1 : AksharaSpacing.s2,
                  ),
                  Text(
                    label,
                    style: labelStyle,
                    maxLines: compact ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _StatusKpiCard extends StatelessWidget {
  const _StatusKpiCard({
    required this.value,
    required this.label,
    required this.detail,
    required this.accent,
    required this.icon,
    required this.height,
    this.onTap,
  });

  final String value;
  final String label;
  final String detail;
  final KpiAccent accent;
  final IconData icon;
  final double height;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;
    final accentColors = accent.resolve(context);

    return Material(
      color: accentColors.container,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: AksharaRadius.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: AksharaRadius.card,
        child: SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.all(AksharaSpacing.s3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 18, color: accentColors.foreground),
                    const SizedBox(width: AksharaSpacing.s1),
                    Expanded(
                      child: Text(
                        value,
                        style: text.titleSmall.copyWith(
                          color: accentColors.foreground,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Text(
                  label,
                  style: text.labelSmall.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  detail,
                  style: text.bodySmall.copyWith(
                    color: colors.onSurfaceVariant,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CountKpiCard extends StatelessWidget {
  const _CountKpiCard({
    required this.count,
    required this.label,
    required this.detail,
    required this.accent,
    required this.icon,
    required this.height,
    this.onTap,
  });

  final int count;
  final String label;
  final String detail;
  final KpiAccent accent;
  final IconData icon;
  final double height;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;
    final accentColors = accent.resolve(context);

    return Material(
      color: accentColors.container,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: AksharaRadius.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: AksharaRadius.card,
        child: SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.all(AksharaSpacing.s3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 18, color: accentColors.foreground),
                    const SizedBox(width: AksharaSpacing.s1),
                    Text(
                      '$count',
                      style: text.titleSmall.copyWith(
                        color: accentColors.foreground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                Text(
                  label,
                  style: text.labelSmall.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  detail,
                  style: text.bodySmall.copyWith(
                    color: colors.onSurfaceVariant,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
