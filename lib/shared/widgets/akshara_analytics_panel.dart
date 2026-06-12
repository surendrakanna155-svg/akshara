import 'package:flutter/material.dart';

import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';
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
                  FilterChip(
                    label: Text(filters[i]),
                    selected: selectedIndex == i,
                    onSelected: (_) => onSelected(i),
                    showCheckmark: false,
                    selectedColor: colors.primaryContainer,
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

/// Shows export queued feedback for report screens.
void showAksharaExportQueuedSnackBar(BuildContext context, {String? label}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        label ?? 'Export queued — download will start shortly.',
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
