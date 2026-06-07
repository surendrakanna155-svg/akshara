import 'package:flutter/material.dart';

import '../../../shared/widgets/akshara_kpi_card.dart';
import '../../../theme/theme_extensions.dart';
import '../../finance/widgets/finance_responsive_grid.dart';
import '../transport_models.dart';

/// KPI tiles for transport dashboards using shared [AksharaKpiCard].
class TransportKpiRow extends StatelessWidget {
  const TransportKpiRow({
    super.key,
    required this.kpis,
    this.desktopColumns = 3,
    this.cardHeight = 120,
  });

  final List<TransportKpi> kpis;
  final int desktopColumns;
  final double cardHeight;

  KpiAccent _accent(String name) => switch (name) {
        'primary' => KpiAccent.primary,
        'success' => KpiAccent.success,
        'warning' => KpiAccent.warning,
        'error' => KpiAccent.error,
        _ => KpiAccent.neutral,
      };

  @override
  Widget build(BuildContext context) {
    return FinanceResponsiveGrid(
      desktopColumns: desktopColumns,
      tabletColumns: 3,
      mobileColumns: 2,
      children: [
        for (final kpi in kpis)
          SizedBox(
            height: cardHeight,
            child: AksharaKpiCard(
              value: kpi.value,
              subtitle: kpi.label,
              icon: kpi.icon,
              accent: _accent(kpi.accentName),
              style: AksharaKpiCardStyle.filled,
              detail: kpi.detail,
              semanticLabel: '${kpi.label}: ${kpi.value}',
            ),
          ),
      ],
    );
  }
}
