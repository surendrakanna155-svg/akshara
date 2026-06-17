import 'package:flutter/material.dart';

import '../../theme/radius.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';
import '../../theme/typography.dart';
import 'akshara_kpi_card.dart';

/// Executive-grade analytics summary row for dashboards and reports.
class AksharaAnalyticsSummaryRow extends StatelessWidget {
  const AksharaAnalyticsSummaryRow({
    super.key,
    required this.metrics,
  });

  final List<AksharaAnalyticsMetric> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;
        if (isWide) {
          return Row(
            children: [
              for (var i = 0; i < metrics.length; i++) ...[
                if (i > 0) const SizedBox(width: AksharaSpacing.s3),
                Expanded(child: _MetricTile(metric: metrics[i])),
              ],
            ],
          );
        }
        return Column(
          children: [
            for (var i = 0; i < metrics.length; i++) ...[
              _MetricTile(metric: metrics[i]),
              if (i < metrics.length - 1)
                const SizedBox(height: AksharaSpacing.s3),
            ],
          ],
        );
      },
    );
  }
}

@immutable
class AksharaAnalyticsMetric {
  const AksharaAnalyticsMetric({
    required this.value,
    required this.label,
    required this.accent,
    this.icon,
    this.detail,
  });

  final String value;
  final String label;
  final KpiAccent accent;
  final IconData? icon;
  final String? detail;
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.metric});

  final AksharaAnalyticsMetric metric;

  @override
  Widget build(BuildContext context) {
    return AksharaKpiCard(
      value: metric.value,
      subtitle: metric.label,
      accent: metric.accent,
      icon: metric.icon,
      detail: metric.detail,
      style: AksharaKpiCardStyle.filled,
    );
  }
}

/// Period / tab filter chips for analytics screens.
class AksharaAnalyticsFilterBar extends StatelessWidget {
  const AksharaAnalyticsFilterBar({
    super.key,
    required this.filters,
    required this.selectedIndex,
    required this.onSelected,
    this.trailing,
  });

  final List<String> filters;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Padding(
      padding: const EdgeInsets.only(bottom: AksharaSpacing.s4),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: AksharaSpacing.s2,
              runSpacing: AksharaSpacing.s2,
              children: [
                for (var i = 0; i < filters.length; i++)
                  _AnalyticsFilterChip(
                    label: filters[i],
                    selected: selectedIndex == i,
                    onTap: () => onSelected(i),
                    colors: colors,
                    text: text,
                  ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AksharaSpacing.s3),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class _AnalyticsFilterChip extends StatelessWidget {
  const _AnalyticsFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.colors,
    required this.text,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme colors;
  final AksharaTextStyles text;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? colors.primaryContainer : colors.surfaceContainerLow,
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
                  ? colors.primary.withValues(alpha: 0.55)
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

/// Shows export preview feedback — does not imply a file was generated.
void showAksharaExportQueuedSnackBar(BuildContext context, {String? label}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        label ??
            'Export preview only — file generation pipeline is not connected yet.',
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
