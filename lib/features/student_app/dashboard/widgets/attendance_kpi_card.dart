import 'package:flutter/material.dart';

import '../../../../shared/semantic_status.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../../theme/radius.dart';
import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import '../student_dashboard_provider.dart';
import '../../../../theme/breakpoints.dart';

/// ST-01 attendance KPI — DS V2 Phase 3 flagship: the headline attendance metric
/// as a premium progress **ring** in the persona accent, over a soft tinted
/// surface. Same footprint/height and tap target as the compact status card it
/// replaces.
class AttendanceKpiCard extends StatelessWidget {
  const AttendanceKpiCard({
    super.key,
    required this.kpi,
    this.onTap,
    this.largeMobileBreakpoint = AksharaBreakpoints.largeMobileMinWidth,
  });

  final AttendanceKpi kpi;
  final VoidCallback? onTap;
  final double largeMobileBreakpoint;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;
    final accent = kpi.tone.kpiAccent.resolve(context);
    final pct = int.tryParse(kpi.value.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    // Grow the card height with the user's text scale (matches AksharaKpiCard's
    // count card next to it) so large accessibility text has headroom.
    final scale = MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.6);

    return AksharaInteractiveSurface(
      onTap: onTap,
      borderRadius: AksharaRadius.kpiCardBorder,
      color: accent.container.withValues(alpha: 0.5),
      border: Border.all(color: accent.foreground.withValues(alpha: 0.14)),
      restingShadowLevel: 0,
      hoverShadowLevel: 1,
      pressedShadowLevel: 2,
      semanticLabel: '${kpi.label}: ${kpi.value}. ${kpi.detail}',
      child: SizedBox(
        height: 96 * scale,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AksharaSpacing.s3,
            vertical: AksharaSpacing.s3,
          ),
          child: Row(
            children: [
              AksharaProgressRing(
                value: pct / 100.0,
                size: 58,
                strokeWidth: 7,
                color: accent.foreground,
                child: Text(
                  kpi.value,
                  style: text.labelLarge.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    height: 1.0,
                  ),
                ),
              ),
              const SizedBox(width: AksharaSpacing.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      kpi.label,
                      style: text.kpiLabel.copyWith(
                        color: colors.onSurfaceVariant,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (kpi.detail.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        kpi.detail,
                        style: text.bodySmall.copyWith(
                          color: accent.foreground,
                          fontWeight: FontWeight.w600,
                          height: 1.1,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Secondary compact KPI for homework count alongside attendance.
class HomeworkCountKpiCard extends StatelessWidget {
  const HomeworkCountKpiCard({
    super.key,
    required this.count,
    required this.label,
    this.onTap,
  });

  final int count;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AksharaKpiCard(
      style: AksharaKpiCardStyle.count,
      value: '$count',
      subtitle: label,
      detail: 'Tap to view all',
      accent: KpiAccent.warning,
      icon: Icons.assignment_outlined,
      height: 96,
      onTap: onTap,
      semanticLabel: '$count $label',
    );
  }
}
