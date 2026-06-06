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
            value: value,
            label: subtitle,
            accent: accent,
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
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
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
              const Spacer(),
              Text(
                value,
                style: text.titleSmall.copyWith(color: colors.onSurface),
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
    required this.value,
    required this.label,
    required this.accent,
    this.onTap,
  });

  final String value;
  final String label;
  final KpiAccent accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;
    final accentColors = accent.resolve(context);

    return Material(
      color: accentColors.container,
      borderRadius: AksharaRadius.card,
      child: InkWell(
        onTap: onTap,
        borderRadius: AksharaRadius.card,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AksharaSpacing.s3,
            vertical: AksharaSpacing.s3,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: text.titleMedium.copyWith(
                  color: accentColors.foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AksharaSpacing.s1),
              Text(
                label,
                style: text.labelSmall.copyWith(
                  color: colors.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
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
            padding: const EdgeInsets.all(AksharaSpacing.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 20, color: accentColors.foreground),
                    const SizedBox(width: AksharaSpacing.s2),
                    Expanded(
                      child: Text(
                        value,
                        style: text.titleMedium.copyWith(
                          color: accentColors.foreground,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AksharaSpacing.s1),
                Text(
                  label,
                  style: text.labelMedium.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  detail,
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
            padding: const EdgeInsets.all(AksharaSpacing.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 20, color: accentColors.foreground),
                    const SizedBox(width: AksharaSpacing.s2),
                    Text(
                      '$count',
                      style: text.titleMedium.copyWith(
                        color: accentColors.foreground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AksharaSpacing.s1),
                Text(
                  label,
                  style: text.labelMedium.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  detail,
                  style: text.bodySmall.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
