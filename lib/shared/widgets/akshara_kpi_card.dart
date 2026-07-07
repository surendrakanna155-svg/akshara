import 'package:flutter/material.dart';

import '../../theme/motion.dart';
import '../../theme/radius.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';
import '../../theme/typography.dart';
import 'akshara_interactive_surface.dart';

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

/// Trend direction for optional KPI delta indicators (visual only).
enum AksharaKpiTrendDirection { up, down, neutral }

/// Grows a fixed KPI-card height with the user's text-scale so large
/// accessibility text and tall Indic (Noto) scripts get headroom instead of
/// clipping. Clamped at 1.6× so very large scales don't make cards absurdly
/// tall — beyond that the existing `maxLines:1 + ellipsis` degrades gracefully.
/// At the default 1.0 scale the height is unchanged (zero golden churn).
double _scaledKpiHeight(BuildContext context, double base) {
  final scale = MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.6);
  return base * scale;
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
    this.trendDirection,
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
  final Key? drillKey;
  final AksharaKpiTrendDirection? trendDirection;

  static const double iconBoxSize = 36;

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
            detail: detail,
            trendDirection: trendDirection,
            onTap: onTap,
          ),
        AksharaKpiCardStyle.filled => _FilledKpiTile(
            drillKey: drillKey,
            value: value,
            label: subtitle,
            accent: accent,
            icon: icon,
            detail: detail,
            trendDirection: trendDirection,
            onTap: onTap,
          ),
        AksharaKpiCardStyle.status => _StatusKpiCard(
            value: value,
            label: subtitle,
            detail: detail ?? '',
            accent: accent,
            icon: icon ?? Icons.fact_check_outlined,
            height: height,
            trendDirection: trendDirection,
            onTap: onTap,
          ),
        AksharaKpiCardStyle.count => _CountKpiCard(
            count: int.tryParse(value) ?? 0,
            label: subtitle,
            detail: detail ?? 'Tap to view all',
            accent: accent,
            icon: icon ?? Icons.assignment_outlined,
            height: height,
            trendDirection: trendDirection,
            onTap: onTap,
          ),
      },
    );
  }
}

/// Presentation helper — classifies existing [detail] strings for trend chips.
abstract final class AksharaKpiPresentation {
  static bool isTrendDetail(String? detail) {
    if (detail == null || detail.trim().isEmpty) {
      return false;
    }
    final trimmed = detail.trim();
    if (trimmed.contains('%')) {
      return true;
    }
    if (trimmed.startsWith('+') || trimmed.startsWith('-')) {
      return RegExp(r'^[\+\-]\d').hasMatch(trimmed);
    }
    return trimmed.toLowerCase().contains(' vs ');
  }

  static AksharaKpiTrendDirection inferTrendDirection(
    String detail, {
    AksharaKpiTrendDirection? override,
  }) {
    if (override != null) {
      return override;
    }
    final trimmed = detail.trim();
    if (trimmed.startsWith('+') ||
        trimmed.toLowerCase().contains('increase') ||
        trimmed.toLowerCase().contains('up ')) {
      return AksharaKpiTrendDirection.up;
    }
    if (RegExp(r'^-\d').hasMatch(trimmed) ||
        trimmed.toLowerCase().contains('decrease') ||
        trimmed.toLowerCase().contains('down ')) {
      return AksharaKpiTrendDirection.down;
    }
    return AksharaKpiTrendDirection.neutral;
  }
}

class _KpiIconBadge extends StatelessWidget {
  const _KpiIconBadge({
    required this.icon,
    required this.foreground,
    required this.background,
    this.size = AksharaKpiCard.iconBoxSize,
    this.iconSize = 20,
  });

  final IconData icon;
  final Color foreground;
  final Color background;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        borderRadius: AksharaRadius.chip,
      ),
      child: Icon(icon, size: iconSize, color: foreground),
    );
  }
}

class _KpiTrendChip extends StatelessWidget {
  const _KpiTrendChip({
    required this.label,
    required this.direction,
  });

  final String label;
  final AksharaKpiTrendDirection direction;

  @override
  Widget build(BuildContext context) {
    final ext = context.akshara;
    final colors = context.colors;
    final text = context.aksharaText;

    final (Color bg, Color fg, IconData icon) = switch (direction) {
      AksharaKpiTrendDirection.up => (
          ext.successContainer,
          ext.success,
          Icons.trending_up_rounded,
        ),
      AksharaKpiTrendDirection.down => (
          colors.errorContainer,
          colors.error,
          Icons.trending_down_rounded,
        ),
      AksharaKpiTrendDirection.neutral => (
          colors.surfaceContainerHigh,
          colors.onSurfaceVariant,
          Icons.trending_flat_rounded,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AksharaSpacing.s2,
        vertical: AksharaSpacing.s1,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AksharaRadius.xs),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: AksharaSpacing.s1),
          Flexible(
            child: Text(
              label,
              style: text.labelSmall.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
                height: 1.1,
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

class _KpiAccentStripe extends StatelessWidget {
  const _KpiAccentStripe({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.horizontal(
          left: Radius.circular(AksharaRadius.lg),
        ),
      ),
    );
  }
}

IconData _defaultIcon(KpiAccent accent) {
  return switch (accent) {
    KpiAccent.success => Icons.check_circle_outline,
    KpiAccent.error => Icons.cancel_outlined,
    KpiAccent.warning => Icons.schedule,
    KpiAccent.primary => Icons.insights_outlined,
    KpiAccent.neutral => Icons.analytics_outlined,
    KpiAccent.tertiary => Icons.trending_up_outlined,
    KpiAccent.indigo => Icons.auto_graph_outlined,
  };
}

class _StripKpiCard extends StatelessWidget {
  const _StripKpiCard({
    required this.value,
    required this.subtitle,
    required this.accent,
    this.icon,
    this.detail,
    this.trendDirection,
    this.onTap,
  });

  final String value;
  final String subtitle;
  final KpiAccent accent;
  final IconData? icon;
  final String? detail;
  final AksharaKpiTrendDirection? trendDirection;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;
    final accentColors = accent.resolve(context);
    final resolvedIcon = icon ?? _defaultIcon(accent);
    final showTrend = AksharaKpiPresentation.isTrendDetail(detail);

    return AksharaInteractiveSurface(
      onTap: onTap,
      borderRadius: AksharaRadius.kpiCardBorder,
      color: colors.surface,
      border: Border.all(
        color: colors.outlineVariant.withValues(alpha: 0.65),
      ),
      restingShadowLevel: AksharaMotion.restingShadow,
      child: SizedBox(
        height: _scaledKpiHeight(context, 88),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _KpiAccentStripe(color: accentColors.foreground),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AksharaSpacing.s3,
                  AksharaSpacing.s2,
                  AksharaSpacing.s3,
                  AksharaSpacing.s2,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            subtitle,
                            style: text.kpiLabel.copyWith(
                              color: colors.onSurfaceVariant,
                              fontSize: 12,
                              height: 1.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _KpiIconBadge(
                          icon: resolvedIcon,
                          foreground: accentColors.foreground,
                          background: accentColors.container,
                          size: 28,
                          iconSize: 16,
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      value,
                      style: text.titleMedium.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w600,
                        height: 1.05,
                      ).tabularFigures,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (showTrend && detail != null) ...[
                      const SizedBox(height: AksharaSpacing.s1),
                      _KpiTrendChip(
                        label: detail!,
                        direction: AksharaKpiPresentation.inferTrendDirection(
                          detail!,
                          override: trendDirection,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilledKpiTile extends StatelessWidget {
  const _FilledKpiTile({
    this.drillKey,
    required this.value,
    required this.label,
    required this.accent,
    this.icon,
    this.detail,
    this.trendDirection,
    this.onTap,
  });

  final Key? drillKey;
  final String value;
  final String label;
  final KpiAccent accent;
  final IconData? icon;
  final String? detail;
  final AksharaKpiTrendDirection? trendDirection;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;
    final accentColors = accent.resolve(context);
    final resolvedIcon = icon ?? _defaultIcon(accent);
    final showTrend = AksharaKpiPresentation.isTrendDetail(detail);
    final caption = showTrend ? null : detail;

    return AksharaInteractiveSurface(
      drillKey: drillKey,
      onTap: onTap,
      borderRadius: AksharaRadius.kpiCardBorder,
      color: colors.surface,
      border: Border.all(
        color: accentColors.foreground.withValues(alpha: 0.12),
      ),
      restingShadowLevel: AksharaMotion.restingShadow,
      hoverShadowLevel: AksharaMotion.hoverShadow,
      pressedShadowLevel: AksharaMotion.pressedShadow,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final dense = constraints.hasBoundedHeight &&
              constraints.maxHeight <= 148;
          final padding = EdgeInsets.all(
            dense ? AksharaSpacing.s3 : AksharaSpacing.kpiCardPadding,
          );
          final valueStyle = (dense ? text.titleLarge : text.kpiValue).copyWith(
            color: colors.onSurface,
            height: 1.05,
          ).tabularFigures;

          return Padding(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _KpiIconBadge(
                      icon: resolvedIcon,
                      foreground: accentColors.foreground,
                      background: accentColors.container,
                      size: dense ? 32 : AksharaKpiCard.iconBoxSize,
                      iconSize: dense ? 18 : 20,
                    ),
                    const SizedBox(width: AksharaSpacing.s3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: text.kpiLabel.copyWith(
                              color: colors.onSurfaceVariant,
                              fontSize: dense ? 12 : 13,
                            ),
                            maxLines: dense ? 1 : 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(
                            height:
                                dense ? AksharaSpacing.s1 : AksharaSpacing.s2,
                          ),
                          Text(
                            value,
                            style: valueStyle,
                            maxLines: dense ? 1 : 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (onTap != null && !dense)
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 18,
                        color:
                            accentColors.foreground.withValues(alpha: 0.7),
                      ),
                  ],
                ),
                if (showTrend && detail != null) ...[
                  SizedBox(
                    height: dense ? AksharaSpacing.s1 : AksharaSpacing.s2,
                  ),
                  _KpiTrendChip(
                    label: detail!,
                    direction: AksharaKpiPresentation.inferTrendDirection(
                      detail!,
                      override: trendDirection,
                    ),
                  ),
                ] else if (caption != null && caption.isNotEmpty) ...[
                  SizedBox(
                    height: dense ? AksharaSpacing.s1 : AksharaSpacing.s2,
                  ),
                  Text(
                    caption,
                    style: text.bodySmall.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          );
        },
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
    this.trendDirection,
    this.onTap,
  });

  final String value;
  final String label;
  final String detail;
  final KpiAccent accent;
  final IconData icon;
  final double height;
  final AksharaKpiTrendDirection? trendDirection;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;
    final accentColors = accent.resolve(context);
    final showTrend = AksharaKpiPresentation.isTrendDetail(detail);

    return AksharaInteractiveSurface(
      onTap: onTap,
      borderRadius: AksharaRadius.kpiCardBorder,
      color: accentColors.container.withValues(alpha: 0.55),
      border: Border.all(
        color: accentColors.foreground.withValues(alpha: 0.14),
      ),
      restingShadowLevel: 0,
      hoverShadowLevel: 1,
      pressedShadowLevel: 2,
      child: SizedBox(
        height: _scaledKpiHeight(context, height),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _KpiAccentStripe(color: accentColors.foreground),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AksharaSpacing.s3,
                  vertical: AksharaSpacing.s2,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: text.kpiLabel.copyWith(
                        color: colors.onSurfaceVariant,
                        fontSize: 12,
                        height: 1.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AksharaSpacing.s1),
                    Text(
                      value,
                      style: text.titleMedium.copyWith(
                        color: accentColors.foreground,
                        fontWeight: FontWeight.w600,
                        height: 1.05,
                      ).tabularFigures,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (detail.isNotEmpty) ...[
                      const SizedBox(height: AksharaSpacing.s1),
                      if (showTrend)
                        _KpiTrendChip(
                          label: detail,
                          direction:
                              AksharaKpiPresentation.inferTrendDirection(
                            detail,
                            override: trendDirection,
                          ),
                        )
                      else
                        Text(
                          detail,
                          style: text.bodySmall.copyWith(
                            color: colors.onSurfaceVariant,
                            height: 1.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(
                right: AksharaSpacing.s2,
                top: AksharaSpacing.s2,
              ),
              child: _KpiIconBadge(
                icon: icon,
                foreground: accentColors.foreground,
                background: accentColors.container,
                size: 28,
                iconSize: 16,
              ),
            ),
          ],
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
    this.trendDirection,
    this.onTap,
  });

  final int count;
  final String label;
  final String detail;
  final KpiAccent accent;
  final IconData icon;
  final double height;
  final AksharaKpiTrendDirection? trendDirection;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;
    final accentColors = accent.resolve(context);
    final showTrend = AksharaKpiPresentation.isTrendDetail(detail);

    return AksharaInteractiveSurface(
      onTap: onTap,
      borderRadius: AksharaRadius.kpiCardBorder,
      color: accentColors.container.withValues(alpha: 0.55),
      border: Border.all(
        color: accentColors.foreground.withValues(alpha: 0.14),
      ),
      restingShadowLevel: 0,
      hoverShadowLevel: 1,
      pressedShadowLevel: 2,
      child: SizedBox(
        height: _scaledKpiHeight(context, height),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _KpiAccentStripe(color: accentColors.foreground),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AksharaSpacing.s3,
                  vertical: AksharaSpacing.s2,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: text.kpiLabel.copyWith(
                        color: colors.onSurfaceVariant,
                        fontSize: 12,
                        height: 1.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AksharaSpacing.s1),
                    Text(
                      '$count',
                      style: text.titleLarge.copyWith(
                        color: accentColors.foreground,
                        fontWeight: FontWeight.w600,
                        height: 1.05,
                      ).tabularFigures,
                    ),
                    if (detail.isNotEmpty) ...[
                      const SizedBox(height: AksharaSpacing.s1),
                      if (showTrend)
                        _KpiTrendChip(
                          label: detail,
                          direction:
                              AksharaKpiPresentation.inferTrendDirection(
                            detail,
                            override: trendDirection,
                          ),
                        )
                      else
                        Text(
                          detail,
                          style: text.bodySmall.copyWith(
                            color: colors.onSurfaceVariant,
                            height: 1.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(
                right: AksharaSpacing.s2,
                top: AksharaSpacing.s2,
              ),
              child: _KpiIconBadge(
                icon: icon,
                foreground: accentColors.foreground,
                background: accentColors.container,
                size: 28,
                iconSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
