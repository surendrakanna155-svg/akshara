import 'package:flutter/material.dart';

import '../../theme/radius.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';
import 'akshara_glass_surface.dart';
import 'akshara_kpi_card.dart';
import 'akshara_sparkline.dart';

/// Executive glass KPI tile with optional sparkline and trend chip (M15.5).
class AksharaExecutiveKpiCard extends StatelessWidget {
  const AksharaExecutiveKpiCard({
    super.key,
    required this.label,
    required this.value,
    this.accent = KpiAccent.primary,
    this.icon,
    this.trendLabel,
    this.trendDirection,
    this.sparklinePoints,
    this.width = 168,
    this.onTap,
  });

  final String label;
  final String value;
  final KpiAccent accent;
  final IconData? icon;
  final String? trendLabel;
  final AksharaKpiTrendDirection? trendDirection;
  final List<double>? sparklinePoints;
  final double width;
  final VoidCallback? onTap;

  /// Decorative sparkline from a numeric seed when live series is unavailable.
  static List<double> decorativeSparkline(String seed, {int points = 8}) {
    var hash = 0;
    for (final codeUnit in seed.codeUnits) {
      hash = (hash * 31 + codeUnit) & 0x7fffffff;
    }
    return List<double>.generate(points, (i) {
      final wave = ((hash >> (i % 12)) & 0xf) / 15;
      return 0.35 + wave * 0.55 + (i / points) * 0.1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;
    final accentColors = accent.resolve(context);
    final resolvedIcon = icon ?? Icons.insights_outlined;
    final points = sparklinePoints ?? decorativeSparkline('$label$value');
    final showTrend = trendLabel != null && trendLabel!.isNotEmpty;

    final card = Semantics(
      button: onTap != null,
      label: '$label: $value',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AksharaRadius.glass,
          child: AksharaGlassSurface(
            borderRadius: AksharaRadius.glass,
            padding: const EdgeInsets.all(AksharaSpacing.s4),
            showSheen: true,
            enableBlur: false,
            tintColor: colors.surface,
            opacity: context.akshara.glassOpacity + 0.04,
            borderOpacity: context.akshara.glassBorderOpacity + 0.06,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
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
                    const SizedBox(width: AksharaSpacing.s2),
                    Expanded(
                      child: Text(
                        label,
                        style: text.kpiLabel.copyWith(
                          color: colors.onSurfaceVariant,
                          height: 1.15,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AksharaSpacing.s2),
                Text(
                  value,
                  style: text.kpiValue.copyWith(
                    color: colors.onSurface,
                    height: 1.05,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (showTrend) ...[
                  const SizedBox(height: AksharaSpacing.s2),
                  _ExecutiveTrendChip(
                    label: trendLabel!,
                    direction: trendDirection ??
                        AksharaKpiPresentation.inferTrendDirection(
                          trendLabel!,
                        ),
                  ),
                ],
                const SizedBox(height: AksharaSpacing.s2),
                AksharaSparkline(
                  points: points,
                  height: 26,
                  color: accentColors.foreground,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (width.isFinite) {
      return SizedBox(width: width, child: card);
    }
    return card;
  }
}

class _ExecutiveTrendChip extends StatelessWidget {
  const _ExecutiveTrendChip({
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
