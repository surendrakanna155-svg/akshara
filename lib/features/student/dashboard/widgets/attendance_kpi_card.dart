import 'package:flutter/material.dart';

import '../../../../shared/semantic_status.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../../theme/theme_extensions.dart';
import '../student_dashboard_provider.dart';

/// ST-01 attendance KPI compact card (173×88 on mobile).
class AttendanceKpiCard extends StatelessWidget {
  const AttendanceKpiCard({
    super.key,
    required this.kpi,
    this.onTap,
    this.largeMobileBreakpoint = 428,
  });

  final AttendanceKpi kpi;
  final VoidCallback? onTap;
  final double largeMobileBreakpoint;

  @override
  Widget build(BuildContext context) {
    return AksharaKpiCard(
      style: AksharaKpiCardStyle.status,
      value: kpi.value,
      subtitle: kpi.label,
      detail: kpi.detail,
      accent: kpi.tone.kpiAccent,
      icon: Icons.fact_check_outlined,
      height: 96,
      onTap: onTap,
      semanticLabel: '${kpi.label}: ${kpi.value}. ${kpi.detail}',
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
