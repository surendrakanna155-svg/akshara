import 'package:flutter/material.dart';

import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/widgets/akshara_kpi_card.dart';
import '../../../theme/theme_extensions.dart';
import '../../finance/widgets/finance_responsive_grid.dart';
import '../management_kpi_navigation.dart';
import '../management_models.dart';

/// KPI tiles for management dashboards using shared [AksharaKpiCard].
class ManagementKpiRow extends StatelessWidget {
  const ManagementKpiRow({
    super.key,
    required this.kpis,
    this.desktopColumns = 4,
    this.cardHeight = 132,
  });

  final List<ManagementKpi> kpis;
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
              drillKey: managementKpiIsDrillable(kpi)
                  ? QaTestKeys.managementKpiDrillButton(kpi.id)
                  : null,
              value: kpi.value,
              subtitle: kpi.label,
              icon: kpi.icon,
              accent: _accent(kpi.accentName),
              style: AksharaKpiCardStyle.filled,
              detail: kpi.detail,
              semanticLabel: '${kpi.label}: ${kpi.value}',
              onTap: managementKpiIsDrillable(kpi)
                  ? () => navigateManagementKpiDrill(context, kpi)
                  : null,
            ),
          ),
      ],
    );
  }
}
