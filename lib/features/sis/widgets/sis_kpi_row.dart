import 'package:flutter/material.dart';

import '../../../shared/widgets/akshara_kpi_card.dart';
import '../../../theme/theme_extensions.dart';
import '../sis_models.dart';
import 'sis_responsive_grid.dart';

class SisKpiRow extends StatelessWidget {
  const SisKpiRow({
    super.key,
    required this.kpis,
    this.desktopColumns = 6,
    this.cardHeight = 120,
  });

  final List<SisKpi> kpis;
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
    return SisResponsiveGrid(
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
