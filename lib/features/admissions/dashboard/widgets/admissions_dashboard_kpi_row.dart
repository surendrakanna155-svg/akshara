import 'package:flutter/material.dart';

import '../../../../shared/widgets/akshara_kpi_card.dart';
import '../../../../theme/theme_extensions.dart';
import '../../admissions_models.dart';
import '../../widgets/admissions_responsive_grid.dart';

/// Six KPI tiles for AD-01 (176×120 desktop reference).
class AdmissionsDashboardKpiRow extends StatelessWidget {
  const AdmissionsDashboardKpiRow({
    super.key,
    required this.kpis,
  });

  final List<AdmissionsKpi> kpis;

  KpiAccent _accent(String name) => switch (name) {
        'primary' => KpiAccent.primary,
        'success' => KpiAccent.success,
        'warning' => KpiAccent.warning,
        'error' => KpiAccent.error,
        _ => KpiAccent.neutral,
      };

  @override
  Widget build(BuildContext context) {
    return AdmissionsResponsiveGrid(
      desktopColumns: 6,
      tabletColumns: 3,
      mobileColumns: 2,
      children: [
        for (final kpi in kpis)
          SizedBox(
            height: 120,
            child: AksharaKpiCard(
              value: kpi.value,
              subtitle: kpi.label,
              icon: kpi.icon,
              accent: _accent(kpi.accentName),
              style: AksharaKpiCardStyle.filled,
              semanticLabel: '${kpi.label}: ${kpi.value}',
            ),
          ),
      ],
    );
  }
}
