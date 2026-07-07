import 'package:flutter/material.dart';

import '../../../shared/widgets/akshara_executive_kpi_card.dart';
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
    this.cardHeight = 172,
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
            child: AksharaExecutiveKpiCard(
              label: kpi.label,
              value: kpi.value,
              icon: kpi.icon,
              accent: _accent(kpi.accentName),
              width: double.infinity,
              trendLabel: AksharaKpiPresentation.isTrendDetail(kpi.detail)
                  ? kpi.detail
                  : null,
              trendDirection: kpi.detail != null &&
                      AksharaKpiPresentation.isTrendDetail(kpi.detail)
                  ? AksharaKpiPresentation.inferTrendDirection(kpi.detail!)
                  : null,
              onTap: managementKpiIsDrillable(kpi)
                  ? () => navigateManagementKpiDrill(context, kpi)
                  : null,
            ),
          ),
      ],
    );
  }
}
